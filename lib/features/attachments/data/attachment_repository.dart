import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'attachment_local_data_source.dart';
import 'attachment_model.dart';
import 'attachment_remote_data_source.dart';

/// Owns the `attachments` table's offline-first lifecycle. Two things set
/// this apart from every other [Syncable] repository:
///
///  - Its parent FK (`attachableType` + `attachableLocalUuid`) must resolve
///    to the parent note/reminder's `server_uuid` before a create/delete
///    can be pushed — same pattern as `ReminderRepository`'s note FK — so
///    this repository must be registered with [SyncManager] *after* both
///    the notes and reminders repositories.
///  - There is no list endpoint: [pull] is a no-op here. New/removed
///    attachments are discovered as a side effect of `NoteRepository` and
///    `ReminderRepository` reconciling the nested `attachments` array their
///    own pull already receives, via [reconcileNested].
class AttachmentRepository implements Syncable {
  AttachmentRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
  });

  final AttachmentLocalDataSource _local;
  final AttachmentRemoteDataSource _remote;
  final SyncManager _syncManager;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<AttachmentModel>> getFor({
    required String attachableType,
    required String attachableLocalUuid,
  }) => _local.getFor(
    attachableType: attachableType,
    attachableLocalUuid: attachableLocalUuid,
  );

  /// Copies [sourcePath] into the app's own documents directory (so it
  /// survives even if the picker's source, e.g. a share-sheet temp file,
  /// gets cleared) and queues it for upload.
  Future<AttachmentModel> addFromFile({
    required String attachableType,
    required String attachableLocalUuid,
    required String sourcePath,
    required String filename,
    String? mimeType,
  }) async {
    final localUuid = _local.newLocalUuid();
    final storedPath = await _copyIntoAppStorage(
      localUuid: localUuid,
      sourcePath: sourcePath,
      filename: filename,
    );
    final size = await File(storedPath).length();

    final attachment = AttachmentModel(
      localUuid: localUuid,
      attachableType: attachableType,
      attachableLocalUuid: attachableLocalUuid,
      localFilePath: storedPath,
      filename: filename,
      mimeType: mimeType,
      size: size,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(attachment);
    _notifyAndSync();

    return attachment;
  }

  Future<void> deleteAttachment(AttachmentModel attachment) async {
    if (attachment.serverUuid == null) {
      await _local.deleteHard(attachment.localUuid);
    } else {
      await _local.markPendingDelete(attachment.localUuid);
    }
    _notifyAndSync();
  }

  /// Fetches and caches the file for a pulled attachment that has no local
  /// copy yet (tap-to-view). No-ops if already downloaded.
  Future<AttachmentModel> downloadIfNeeded(AttachmentModel attachment) async {
    if (attachment.localFilePath != null || attachment.serverUuid == null) {
      return attachment;
    }
    final parentServerUuid = await _local.parentServerUuidFor(
      attachableType: attachment.attachableType,
      attachableLocalUuid: attachment.attachableLocalUuid,
    );
    if (parentServerUuid == null) {
      return attachment;
    }
    final bytes = await _remote.download(
      attachableType: attachment.attachableType,
      parentServerUuid: parentServerUuid,
      attachmentServerUuid: attachment.serverUuid!,
    );
    final storedPath = await _copyBytesIntoAppStorage(
      localUuid: attachment.localUuid,
      filename: attachment.filename,
      bytes: bytes,
    );
    await _local.setLocalFilePath(
      localUuid: attachment.localUuid,
      localFilePath: storedPath,
    );

    return attachment.copyWith(localFilePath: storedPath);
  }

  /// Called by `NoteRepository`/`ReminderRepository` while reconciling a
  /// pulled note/reminder's nested `attachments` array — the only place new
  /// server-side attachments (or ones deleted server-side) are discovered,
  /// since there's no standalone list endpoint to pull from directly.
  Future<void> reconcileNested({
    required String attachableType,
    required String attachableLocalUuid,
    required List<dynamic> attachmentsJson,
  }) async {
    final seenServerUuids = <String>{};
    for (final raw in attachmentsJson) {
      final json = raw as Map<String, dynamic>;
      final serverUuid = json['uuid'] as String;
      seenServerUuids.add(serverUuid);
      final existingLocalUuid = await _local.localUuidForServerUuid(serverUuid);
      if (existingLocalUuid != null) {
        continue; // Already known locally — attachments are immutable, nothing to update.
      }
      await _local.upsert(
        AttachmentModel.fromApiJson(
          json,
          localUuid: _local.newLocalUuid(),
          attachableType: attachableType,
          attachableLocalUuid: attachableLocalUuid,
        ),
      );
    }

    final staleUuids = (await _local.syncedServerUuidsFor(
      attachableType: attachableType,
      attachableLocalUuid: attachableLocalUuid,
    )).difference(seenServerUuids);
    for (final serverUuid in staleUuids) {
      final localUuid = await _local.localUuidForServerUuid(serverUuid);
      if (localUuid != null) {
        await _local.deleteHard(localUuid);
      }
    }
    _changesController.add(null);
  }

  void _notifyAndSync() {
    _changesController.add(null);
    unawaited(_syncManager.runSync());
  }

  @override
  Future<void> pushPending() async {
    final rows = await _local.pendingRows();
    for (final row in rows) {
      final attachment = AttachmentModel.fromRow(row);
      try {
        await switch (attachment.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(attachment),
          SyncStatus.pendingDelete => _pushDelete(attachment),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  Future<void> _pushCreate(AttachmentModel attachment) async {
    final parentServerUuid = await _local.parentServerUuidFor(
      attachableType: attachment.attachableType,
      attachableLocalUuid: attachment.attachableLocalUuid,
    );
    if (parentServerUuid == null) {
      // Parent note/reminder hasn't synced yet — try again next sync pass.
      return;
    }
    final json = await _remote.create(
      attachableType: attachment.attachableType,
      parentServerUuid: parentServerUuid,
      filePath: attachment.localFilePath!,
      filename: attachment.filename,
    );
    await _local.markSynced(
      localUuid: attachment.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushDelete(AttachmentModel attachment) async {
    final parentServerUuid = await _local.parentServerUuidFor(
      attachableType: attachment.attachableType,
      attachableLocalUuid: attachment.attachableLocalUuid,
    );
    if (parentServerUuid != null) {
      await _remote.delete(
        attachableType: attachment.attachableType,
        parentServerUuid: parentServerUuid,
        attachmentServerUuid: attachment.serverUuid!,
      );
    }
    if (attachment.localFilePath != null) {
      final file = File(attachment.localFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _local.deleteHard(attachment.localUuid);
  }

  /// No standalone list endpoint exists — see the class doc-comment.
  /// [SyncManager] still calls this (every [Syncable] must implement it),
  /// so it's a deliberate no-op rather than an unused method.
  @override
  Future<void> pull() async {}

  Future<String> _copyIntoAppStorage({
    required String localUuid,
    required String sourcePath,
    required String filename,
  }) async {
    final dir = await _attachmentsDirectory();
    final destination = File(p.join(dir.path, '${localUuid}_$filename'));
    await File(sourcePath).copy(destination.path);

    return destination.path;
  }

  Future<String> _copyBytesIntoAppStorage({
    required String localUuid,
    required String filename,
    required List<int> bytes,
  }) async {
    final dir = await _attachmentsDirectory();
    final destination = File(p.join(dir.path, '${localUuid}_$filename'));
    await destination.writeAsBytes(bytes);

    return destination.path;
  }

  Future<Directory> _attachmentsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  void dispose() => unawaited(_changesController.close());
}
