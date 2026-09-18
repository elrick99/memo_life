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
import 'tag_local_data_source.dart';

/// Owns the `notes` table's offline-first lifecycle: every mutation writes
/// local-first (so the UI never waits on the network), then asks
/// [SyncManager] to push in the background. [pull]/[pushPending] are called
/// by the sync manager itself, in the dependency order it decides.
class NoteRepository implements Syncable {
  NoteRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
    required this._tags,
    this._attachmentRepository,
  });

  final NoteLocalDataSource _local;
  final NoteRemoteDataSource _remote;
  final SyncManager _syncManager;
  final TagLocalDataSource _tags;
  final AttachmentRepository? _attachmentRepository;
  final _changesController = StreamController<void>.broadcast();

  /// Emits whenever local data changes (a mutation, or a completed
  /// push/pull) — [NotesBloc] re-queries [getNotes] on every event.
  Stream<void> get changes => _changesController.stream;

  Future<List<NoteModel>> getNotes({bool includeArchived = false}) =>
      _local.getAll(includeArchived: includeArchived);

  Future<NoteModel> createNote({
    String? categoryLocalUuid,
    List<String> tagLocalUuids = const [],
    required String title,
    String? content,
    String contentFormat = 'plain',
    List<ChecklistItem> checklist = const [],
    String priority = 'normal',
    String? color,
    String colorMode = 'automatic',
  }) async {
    final note = NoteModel(
      localUuid: _local.newLocalUuid(),
      categoryLocalUuid: categoryLocalUuid,
      tagLocalUuids: tagLocalUuids,
      title: title,
      content: content,
      contentFormat: contentFormat,
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

  Future<void> togglePin(NoteModel note) =>
      updateNote(note.copyWith(isPinned: !note.isPinned));

  Future<void> toggleLock(NoteModel note) =>
      updateNote(note.copyWith(isLocked: !note.isLocked));

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
    final tagUuids = await _tagServerUuidsFor(note.tagLocalUuids);
    if (tagUuids == null) {
      return;
    }
    final json = await _remote.create(
      note.toApiPayload(categoryUuid: categoryUuid, tagUuids: tagUuids),
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
    final tagUuids = await _tagServerUuidsFor(note.tagLocalUuids);
    if (tagUuids == null) {
      return;
    }
    await _remote.update(
      note.serverUuid!,
      note.toApiPayload(categoryUuid: categoryUuid, tagUuids: tagUuids),
    );
    await _local.markSynced(
      localUuid: note.localUuid,
      serverUuid: note.serverUuid!,
    );
  }

  /// Resolves every tag's *local* uuid to its *server* uuid. Returns null
  /// (defer this note to the next sync pass) if any tag hasn't synced yet.
  Future<List<String>?> _tagServerUuidsFor(List<String> tagLocalUuids) async {
    final uuids = <String>[];
    for (final localUuid in tagLocalUuids) {
      final serverUuid = await _tags.serverUuidFor(localUuid);
      if (serverUuid == null) {
        return null;
      }
      uuids.add(serverUuid);
    }

    return uuids;
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
    final tagsJson = json['tags'] as List<dynamic>? ?? const [];
    final tagLocalUuids = <String>[];
    for (final tagJson in tagsJson) {
      final tagLocalUuid = await _tags.localUuidForServer(
        (tagJson as Map<String, dynamic>)['uuid'] as String,
      );
      if (tagLocalUuid != null) {
        tagLocalUuids.add(tagLocalUuid);
      }
    }

    final incoming = NoteModel.fromApiJson(
      json,
      localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      categoryLocalUuid: categoryLocalUuid,
      tagLocalUuids: tagLocalUuids,
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
