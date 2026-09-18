import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'category_local_data_source.dart';
import 'category_model.dart';
import 'category_remote_data_source.dart';

class CategoryRepository implements Syncable {
  CategoryRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
  });

  final CategoryLocalDataSource _local;
  final CategoryRemoteDataSource _remote;
  final SyncManager _syncManager;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<CategoryModel>> getCategories() => _local.getAll();

  Future<CategoryModel?> getCategory(String localUuid) =>
      _local.getByLocalUuid(localUuid);

  Future<CategoryModel> createCategory({
    required String name,
    String type = 'expense',
    String? color,
    String? icon,
  }) async {
    final category = CategoryModel(
      localUuid: _local.newLocalUuid(),
      name: name,
      type: type,
      color: color,
      icon: icon,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(category);
    _notifyAndSync();

    return category;
  }

  /// System categories can't be deleted (mirrors the backend's own check,
  /// so the UI can disable the action rather than round-trip a 404).
  Future<void> deleteCategory(CategoryModel category) async {
    if (category.isSystem) {
      return;
    }
    if (category.serverUuid == null) {
      await _local.deleteHard(category.localUuid);
    } else {
      await _local.markPendingDelete(category.localUuid);
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
      final category = CategoryModel.fromRow(row);
      try {
        await switch (category.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(category),
          SyncStatus.pendingDelete => _pushDelete(category),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  Future<void> _pushCreate(CategoryModel category) async {
    final json = await _remote.create(category.toApiPayload());
    await _local.markSynced(
      localUuid: category.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushDelete(CategoryModel category) async {
    await _remote.delete(category.serverUuid!);
    await _local.deleteHard(category.localUuid);
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
    // No `updated_at` on CategoryResource — see ReminderRepository for the
    // same reasoning: a `synced` row here has no pending edit to protect.
    await _local.upsert(
      CategoryModel.fromApiJson(
        json,
        localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      ),
    );
  }

  void dispose() => unawaited(_changesController.close());
}
