import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'tag_local_data_source.dart';
import 'tag_model.dart';
import 'tag_remote_data_source.dart';

class TagRepository implements Syncable {
  TagRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
  });

  final TagLocalDataSource _local;
  final TagRemoteDataSource _remote;
  final SyncManager _syncManager;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<TagModel>> getTags() => _local.getAll();

  Future<TagModel> createTag({required String name, String? color}) async {
    final tag = TagModel(
      localUuid: _local.newLocalUuid(),
      name: name,
      color: color,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(tag);
    _notifyAndSync();

    return tag;
  }

  Future<void> deleteTag(TagModel tag) async {
    if (tag.serverUuid == null) {
      await _local.deleteHard(tag.localUuid);
    } else {
      await _local.markPendingDelete(tag.localUuid);
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
      final tag = TagModel.fromRow(row);
      try {
        await switch (tag.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(tag),
          SyncStatus.pendingDelete => _pushDelete(tag),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  Future<void> _pushCreate(TagModel tag) async {
    final json = await _remote.create(tag.toApiPayload());
    await _local.markSynced(
      localUuid: tag.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushDelete(TagModel tag) async {
    await _remote.delete(tag.serverUuid!);
    await _local.deleteHard(tag.localUuid);
  }

  @override
  Future<void> pull() async {
    final items = await _remote.index();
    final seenServerUuids = <String>{};
    for (final json in items) {
      final serverUuid = json['uuid'] as String;
      seenServerUuids.add(serverUuid);
      await _reconcile(json, serverUuid);
    }

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

    if (existing != null && existing.syncStatus != SyncStatus.synced) {
      return;
    }
    // No `updated_at` on TagResource — see CategoryRepository for the same
    // reasoning: a `synced` row here has no pending edit to protect.
    await _local.upsert(
      TagModel.fromApiJson(
        json,
        localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      ),
    );
  }

  void dispose() => unawaited(_changesController.close());
}
