import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'account_local_data_source.dart';
import 'account_model.dart';
import 'account_remote_data_source.dart';

class AccountRepository implements Syncable {
  AccountRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
  });

  final AccountLocalDataSource _local;
  final AccountRemoteDataSource _remote;
  final SyncManager _syncManager;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<AccountModel>> getAccounts() => _local.getAll();

  Future<bool> hasTransactions(String localUuid) =>
      _local.hasTransactions(localUuid);

  /// Called by `TransactionRepository` when a transaction affecting this
  /// account is created/edited/deleted offline — purely a local, optimistic
  /// projection (never pushed; see [AccountLocalDataSource.adjustBalanceLocally]).
  Future<void> adjustBalanceLocally(String localUuid, double delta) async {
    await _local.adjustBalanceLocally(localUuid, delta);
    _changesController.add(null);
  }

  Future<AccountModel> createAccount({
    required String name,
    String type = 'cash',
    double balance = 0,
    String currency = 'XOF',
    String? color,
  }) async {
    final account = AccountModel(
      localUuid: _local.newLocalUuid(),
      name: name,
      type: type,
      balance: balance,
      currency: currency,
      color: color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _local.upsert(account);
    _notifyAndSync();

    return account;
  }

  Future<void> updateAccount(AccountModel account) async {
    final pendingStatus = account.serverUuid == null
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    await _local.upsert(
      account.copyWith(updatedAt: DateTime.now(), syncStatus: pendingStatus),
    );
    _notifyAndSync();
  }

  Future<void> deleteAccount(AccountModel account) async {
    if (account.serverUuid == null) {
      await _local.deleteHard(account.localUuid);
    } else {
      await _local.markPendingDelete(account.localUuid);
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
      final account = AccountModel.fromRow(row);
      try {
        await switch (account.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(account),
          SyncStatus.pendingUpdate => _pushUpdate(account),
          SyncStatus.pendingDelete => _pushDelete(account),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  Future<void> _pushCreate(AccountModel account) async {
    final json = await _remote.create(account.toApiPayload());
    await _local.markSynced(
      localUuid: account.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushUpdate(AccountModel account) async {
    await _remote.update(account.serverUuid!, account.toApiPayload());
    await _local.markSynced(
      localUuid: account.localUuid,
      serverUuid: account.serverUuid!,
    );
  }

  Future<void> _pushDelete(AccountModel account) async {
    await _remote.delete(account.serverUuid!);
    await _local.deleteHard(account.localUuid);
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

    final incoming = AccountModel.fromApiJson(
      json,
      localUuid: existingLocalUuid ?? _local.newLocalUuid(),
    );
    if (existing != null && !incoming.updatedAt.isAfter(existing.updatedAt)) {
      return;
    }
    await _local.upsert(incoming);
  }

  void dispose() => unawaited(_changesController.close());
}
