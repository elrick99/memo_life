import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import '../../attachments/data/attachment_repository.dart';
import 'reminder_local_data_source.dart';
import 'reminder_model.dart';
import 'reminder_remote_data_source.dart';

/// Same offline-first shape as `NoteRepository`, with one extra step: a
/// reminder's `note_local_uuid` FK must be resolved to the note's
/// `server_uuid` (API field `note_uuid`) before it can be pushed — which
/// only works once that note has synced, so this repository must be
/// registered with [SyncManager] *after* the notes repository.
class ReminderRepository implements Syncable {
  ReminderRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
    this._attachmentRepository,
  });

  final ReminderLocalDataSource _local;
  final ReminderRemoteDataSource _remote;
  final SyncManager _syncManager;
  final AttachmentRepository? _attachmentRepository;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<ReminderModel>> getReminders() => _local.getAll();

  Future<ReminderModel> createReminder({
    String? noteLocalUuid,
    String? categoryLocalUuid,
    required String title,
    String? description,
    required DateTime dueAt,
    String? location,
    String type = 'task',
    String priority = 'normal',
    String recurrence = 'none',
  }) async {
    final reminder = ReminderModel(
      localUuid: _local.newLocalUuid(),
      noteLocalUuid: noteLocalUuid,
      categoryLocalUuid: categoryLocalUuid,
      title: title,
      description: description,
      dueAt: dueAt,
      location: location,
      type: type,
      priority: priority,
      recurrence: recurrence,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(reminder);
    _notifyAndSync();

    return reminder;
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    final pendingStatus = reminder.serverUuid == null
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    await _local.upsert(
      reminder.copyWith(updatedAt: DateTime.now(), syncStatus: pendingStatus),
    );
    _notifyAndSync();
  }

  Future<void> toggleCompleted(ReminderModel reminder) =>
      updateReminder(reminder.copyWith(isCompleted: !reminder.isCompleted));

  Future<void> togglePin(ReminderModel reminder) =>
      updateReminder(reminder.copyWith(isPinned: !reminder.isPinned));

  Future<void> deleteReminder(ReminderModel reminder) async {
    if (reminder.serverUuid == null) {
      await _local.deleteHard(reminder.localUuid);
    } else {
      await _local.markPendingDelete(reminder.localUuid);
    }
    _notifyAndSync();
  }

  void _notifyAndSync() {
    _changesController.add(null);
    unawaited(_syncManager.runSync());
  }

  @override
  Future<void> pushPending() async {
    final rows = await _local.pendingRows();
    for (final row in rows) {
      final reminder = ReminderModel.fromRow(row);
      try {
        await switch (reminder.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(reminder),
          SyncStatus.pendingUpdate => _pushUpdate(reminder),
          SyncStatus.pendingDelete => _pushDelete(reminder),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass — see NoteRepository.pushPending.
      }
    }
  }

  Future<void> _pushCreate(ReminderModel reminder) async {
    final noteUuid = await _local.noteServerUuidFor(reminder.noteLocalUuid);
    if (reminder.noteLocalUuid != null && noteUuid == null) {
      // Linked note hasn't synced yet — try again next sync pass instead
      // of creating the reminder without its note link.
      return;
    }
    final categoryUuid = await _local.categoryServerUuidFor(
      reminder.categoryLocalUuid,
    );
    if (reminder.categoryLocalUuid != null && categoryUuid == null) {
      return;
    }
    final json = await _remote.create(
      reminder.toApiPayload(noteUuid: noteUuid, categoryUuid: categoryUuid),
    );
    await _local.markSynced(
      localUuid: reminder.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushUpdate(ReminderModel reminder) async {
    final noteUuid = await _local.noteServerUuidFor(reminder.noteLocalUuid);
    if (reminder.noteLocalUuid != null && noteUuid == null) {
      return;
    }
    final categoryUuid = await _local.categoryServerUuidFor(
      reminder.categoryLocalUuid,
    );
    if (reminder.categoryLocalUuid != null && categoryUuid == null) {
      return;
    }
    await _remote.update(
      reminder.serverUuid!,
      reminder.toApiPayload(noteUuid: noteUuid, categoryUuid: categoryUuid),
    );
    await _local.markSynced(
      localUuid: reminder.localUuid,
      serverUuid: reminder.serverUuid!,
    );
  }

  Future<void> _pushDelete(ReminderModel reminder) async {
    await _remote.delete(reminder.serverUuid!);
    await _local.deleteHard(reminder.localUuid);
  }

  @override
  Future<void> pull() async {
    final seenServerUuids = <String>{};
    var page = 1;
    var lastPage = 1;

    do {
      final result = await _remote.index(page: page);
      lastPage = result.lastPage;
      for (final json in result.items) {
        final serverUuid = json['uuid'] as String;
        seenServerUuids.add(serverUuid);
        await _reconcile(json, serverUuid);
      }
      page++;
    } while (page <= lastPage);

    final staleUuids = (await _local.syncedServerUuids()).difference(
      seenServerUuids,
    );
    for (final serverUuid in staleUuids) {
      final localUuid = await _local.localUuidForServerUuid(serverUuid);
      if (localUuid != null) {
        await _local.deleteHard(localUuid);
      }
    }

    _changesController.add(null);
  }

  Future<void> _reconcile(Map<String, dynamic> json, String serverUuid) async {
    final existingLocalUuid = await _local.localUuidForServerUuid(serverUuid);
    final existing = existingLocalUuid == null
        ? null
        : await _local.getByLocalUuid(existingLocalUuid);

    // Local pending edits win until they've been pushed.
    if (existing != null && existing.syncStatus != SyncStatus.synced) {
      return;
    }

    // `ReminderResource` has no `updated_at`, so — unlike notes — there's
    // no timestamp to compare; any `synced` row is safe to refresh, since
    // reaching here already means there's no local pending edit to protect.
    final noteJson = json['note'] as Map<String, dynamic>?;
    final noteLocalUuid = noteJson == null
        ? null
        : await _local.noteLocalUuidFor(noteJson['uuid'] as String?);
    final categoryJson = json['category'] as Map<String, dynamic>?;
    final categoryLocalUuid = categoryJson == null
        ? null
        : await _local.categoryLocalUuidFor(categoryJson['uuid'] as String?);

    final incoming = ReminderModel.fromApiJson(
      json,
      localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      noteLocalUuid: noteLocalUuid,
      categoryLocalUuid: categoryLocalUuid,
    );
    await _local.upsert(incoming);
    await _attachmentRepository?.reconcileNested(
      attachableType: 'reminder',
      attachableLocalUuid: incoming.localUuid,
      attachmentsJson: json['attachments'] as List<dynamic>? ?? const [],
    );
  }

  void dispose() => unawaited(_changesController.close());
}
