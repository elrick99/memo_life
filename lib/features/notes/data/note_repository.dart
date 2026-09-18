import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import '../../attachments/data/attachment_repository.dart';
import 'checklist_item.dart';
import 'note_local_data_source.dart';
import 'note_model.dart';
import 'note_remote_data_source.dart';

/// Owns the `notes` table's offline-first lifecycle: every mutation writes
/// local-first (so the UI never waits on the network), then asks
/// [SyncManager] to push in the background. [pull]/[pushPending] are called
/// by the sync manager itself, in the dependency order it decides.
class NoteRepository implements Syncable {
  NoteRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
    this._attachmentRepository,
  });

  final NoteLocalDataSource _local;
  final NoteRemoteDataSource _remote;
  final SyncManager _syncManager;
  final AttachmentRepository? _attachmentRepository;
  final _changesController = StreamController<void>.broadcast();

  /// Emits whenever local data changes (a mutation, or a completed
  /// push/pull) — [NotesBloc] re-queries [getNotes] on every event.
  Stream<void> get changes => _changesController.stream;

  Future<List<NoteModel>> getNotes({bool includeArchived = false}) =>
      _local.getAll(includeArchived: includeArchived);

  Future<NoteModel> createNote({
    String? categoryLocalUuid,
    required String title,
    String? content,
    List<ChecklistItem> checklist = const [],
    String priority = 'normal',
    String? color,
    String colorMode = 'automatic',
  }) async {
    final note = NoteModel(
      localUuid: _local.newLocalUuid(),
      categoryLocalUuid: categoryLocalUuid,
      title: title,
      content: content,
      checklist: checklist,
      priority: priority,
      color: color,
      colorMode: colorMode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _local.upsert(note);
    _notifyAndSync();

    return note;
  }

  Future<void> updateNote(NoteModel note) async {
    final pendingStatus = note.serverUuid == null
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    await _local.upsert(
      note.copyWith(updatedAt: DateTime.now(), syncStatus: pendingStatus),
    );
    _notifyAndSync();
  }

  Future<void> toggleArchive(NoteModel note) =>
      updateNote(note.copyWith(isArchived: !note.isArchived));

  Future<void> deleteNote(NoteModel note) async {
    if (note.serverUuid == null) {
      // Never synced — nothing on the server to tell, just drop it.
      await _local.deleteHard(note.localUuid);
    } else {
      await _local.markPendingDelete(note.localUuid);
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
      final note = NoteModel.fromRow(row);
      try {
        await switch (note.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(note),
          SyncStatus.pendingUpdate => _pushUpdate(note),
          SyncStatus.pendingDelete => _pushDelete(note),
          _ => Future.value(),
        };
      } on ApiException {
        // Leave this row pending; it'll be retried on the next sync pass.
        // One bad row (validation error, 404 because it was deleted
        // server-side, ...) must not block the rest of the queue.
      }
    }
  }

  Future<void> _pushCreate(NoteModel note) async {
    final categoryUuid = await _local.categoryServerUuidFor(
      note.categoryLocalUuid,
    );
    if (note.categoryLocalUuid != null && categoryUuid == null) {
      // Linked category hasn't synced yet — try again next sync pass
      // instead of creating the note without its category link.
      return;
    }
    final json = await _remote.create(
      note.toApiPayload(categoryUuid: categoryUuid),
    );
    await _local.markSynced(
      localUuid: note.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushUpdate(NoteModel note) async {
    final categoryUuid = await _local.categoryServerUuidFor(
      note.categoryLocalUuid,
    );
    if (note.categoryLocalUuid != null && categoryUuid == null) {
      return;
    }
    await _remote.update(
      note.serverUuid!,
      note.toApiPayload(categoryUuid: categoryUuid),
    );
    await _local.markSynced(
      localUuid: note.localUuid,
      serverUuid: note.serverUuid!,
    );
  }

  Future<void> _pushDelete(NoteModel note) async {
    await _remote.delete(note.serverUuid!);
    await _local.deleteHard(note.localUuid);
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

    // Local pending edits win over a stale pull until they've been pushed.
    if (existing != null && existing.syncStatus != SyncStatus.synced) {
      return;
    }

    final categoryJson = json['category'] as Map<String, dynamic>?;
    final categoryLocalUuid = categoryJson == null
        ? null
        : await _local.categoryLocalUuidFor(categoryJson['uuid'] as String?);

    final incoming = NoteModel.fromApiJson(
      json,
      localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      categoryLocalUuid: categoryLocalUuid,
    );
    if (existing != null && !incoming.updatedAt.isAfter(existing.updatedAt)) {
      return;
    }
    await _local.upsert(incoming);
    await _attachmentRepository?.reconcileNested(
      attachableType: 'note',
      attachableLocalUuid: incoming.localUuid,
      attachmentsJson: json['attachments'] as List<dynamic>? ?? const [],
    );
  }

  void dispose() => unawaited(_changesController.close());
}
