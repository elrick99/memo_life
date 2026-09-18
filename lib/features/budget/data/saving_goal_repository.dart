import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'saving_goal_local_data_source.dart';
import 'saving_goal_model.dart';
import 'saving_goal_remote_data_source.dart';

class SavingGoalRepository implements Syncable {
  SavingGoalRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
  });

  final SavingGoalLocalDataSource _local;
  final SavingGoalRemoteDataSource _remote;
  final SyncManager _syncManager;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<SavingGoalModel>> getSavingGoals() => _local.getAll();

  Future<SavingGoalModel> createSavingGoal({
    required String name,
    required double targetAmount,
    double currentAmount = 0,
    DateTime? targetDate,
    String? color,
  }) async {
    final goal = SavingGoalModel(
      localUuid: _local.newLocalUuid(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      color: color,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(goal);
    _notifyAndSync();

    return goal;
  }

  Future<void> updateSavingGoal(SavingGoalModel goal) async {
    final pendingStatus = goal.serverUuid == null
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    await _local.upsert(
      goal.copyWith(updatedAt: DateTime.now(), syncStatus: pendingStatus),
    );
    _notifyAndSync();
  }

  Future<void> deleteSavingGoal(SavingGoalModel goal) async {
    if (goal.serverUuid == null) {
      await _local.deleteHard(goal.localUuid);
    } else {
      await _local.markPendingDelete(goal.localUuid);
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
      final goal = SavingGoalModel.fromRow(row);
      try {
        await switch (goal.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(goal),
          SyncStatus.pendingUpdate => _pushUpdate(goal),
          SyncStatus.pendingDelete => _pushDelete(goal),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  Future<void> _pushCreate(SavingGoalModel goal) async {
    final json = await _remote.create(goal.toApiPayload());
    await _local.markSynced(
      localUuid: goal.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushUpdate(SavingGoalModel goal) async {
    await _remote.update(goal.serverUuid!, goal.toApiPayload());
    await _local.markSynced(
      localUuid: goal.localUuid,
      serverUuid: goal.serverUuid!,
    );
  }

  Future<void> _pushDelete(SavingGoalModel goal) async {
    await _remote.delete(goal.serverUuid!);
    await _local.deleteHard(goal.localUuid);
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

    if (existing != null && existing.syncStatus != SyncStatus.synced) {
      return;
    }
    // No `updated_at` on SavingGoalResource — see ReminderRepository.
    await _local.upsert(
      SavingGoalModel.fromApiJson(
        json,
        localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      ),
    );
  }

  void dispose() => unawaited(_changesController.close());
}
