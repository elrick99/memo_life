import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/syncable.dart';
import 'account_repository.dart';
import 'transaction_local_data_source.dart';
import 'transaction_model.dart';
import 'transaction_remote_data_source.dart';

/// The most involved of the budget repositories: every write has to keep
/// the affected account balance(s) in sync locally (see
/// [AccountRepository.adjustBalanceLocally]), mirroring what the backend's
/// `RecordTransaction` action does server-side — and every push has to
/// resolve up to three FKs (account, destination account, category) to
/// their `server_uuid`, deferring the whole row if the *required* account
/// FK isn't resolvable yet. Must be registered with [SyncManager] after
/// both accounts and categories.
class TransactionRepository implements Syncable {
  TransactionRepository({
    required this._local,
    required this._remote,
    required this._syncManager,
    required this._accountRepository,
  });

  final TransactionLocalDataSource _local;
  final TransactionRemoteDataSource _remote;
  final SyncManager _syncManager;
  final AccountRepository _accountRepository;
  final _changesController = StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<TransactionModel>> getTransactions() => _local.getAll();

  Future<TransactionModel> createTransaction({
    required String accountLocalUuid,
    String? destinationAccountLocalUuid,
    String? categoryLocalUuid,
    required String type,
    required double amount,
    required DateTime occurredAt,
    String? description,
  }) async {
    final transaction = TransactionModel(
      localUuid: _local.newLocalUuid(),
      accountLocalUuid: accountLocalUuid,
      destinationAccountLocalUuid: destinationAccountLocalUuid,
      categoryLocalUuid: categoryLocalUuid,
      type: type,
      amount: amount,
      occurredAt: occurredAt,
      description: description,
      updatedAt: DateTime.now(),
    );
    await _local.upsert(transaction);
    await _applyImpact(transaction);
    _notifyAndSync();

    return transaction;
  }

  Future<void> updateTransaction(TransactionModel updated) async {
    final previous = await _local.getByLocalUuid(updated.localUuid);
    if (previous != null) {
      await _reverseImpact(previous);
    }
    final pendingStatus = updated.serverUuid == null
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    final toStore = updated.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: pendingStatus,
    );
    await _local.upsert(toStore);
    await _applyImpact(toStore);
    _notifyAndSync();
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _reverseImpact(transaction);
    if (transaction.serverUuid == null) {
      await _local.deleteHard(transaction.localUuid);
    } else {
      await _local.markPendingDelete(transaction.localUuid);
    }
    _notifyAndSync();
  }

  Future<void> _applyImpact(TransactionModel transaction) async {
    if (transaction.type == 'income') {
      await _accountRepository.adjustBalanceLocally(
        transaction.accountLocalUuid,
        transaction.amount,
      );
    } else {
      await _accountRepository.adjustBalanceLocally(
        transaction.accountLocalUuid,
        -transaction.amount,
      );
    }
    if (transaction.type == 'transfer' &&
        transaction.destinationAccountLocalUuid != null) {
      await _accountRepository.adjustBalanceLocally(
        transaction.destinationAccountLocalUuid!,
        transaction.amount,
      );
    }
  }

  Future<void> _reverseImpact(TransactionModel transaction) async {
    if (transaction.type == 'income') {
      await _accountRepository.adjustBalanceLocally(
        transaction.accountLocalUuid,
        -transaction.amount,
      );
    } else {
      await _accountRepository.adjustBalanceLocally(
        transaction.accountLocalUuid,
        transaction.amount,
      );
    }
    if (transaction.type == 'transfer' &&
        transaction.destinationAccountLocalUuid != null) {
      await _accountRepository.adjustBalanceLocally(
        transaction.destinationAccountLocalUuid!,
        -transaction.amount,
      );
    }
  }

  void _notifyAndSync() {
    _changesController.add(null);
    unawaited(_syncManager.runSync());
  }

  @override
  Future<void> pushPending() async {
    final rows = await _local.pendingRows();
    for (final row in rows) {
      final transaction = TransactionModel.fromRow(row);
      try {
        await switch (transaction.syncStatus) {
          SyncStatus.pendingCreate => _pushCreate(transaction),
          SyncStatus.pendingUpdate => _pushUpdate(transaction),
          SyncStatus.pendingDelete => _pushDelete(transaction),
          _ => Future.value(),
        };
      } on ApiException {
        // Retried on the next sync pass.
      }
    }
  }

  /// Resolves the three FKs, or returns null if the *required* account
  /// link isn't resolvable yet (push deferred to the next sync pass).
  Future<Map<String, String?>?> _resolveUuids(
    TransactionModel transaction,
  ) async {
    final accountUuid = await _local.accountServerUuidFor(
      transaction.accountLocalUuid,
    );
    if (accountUuid == null) {
      return null;
    }

    String? destinationUuid;
    if (transaction.destinationAccountLocalUuid != null) {
      destinationUuid = await _local.accountServerUuidFor(
        transaction.destinationAccountLocalUuid,
      );
      if (destinationUuid == null) {
        return null;
      }
    }

    String? categoryUuid;
    if (transaction.categoryLocalUuid != null) {
      categoryUuid = await _local.categoryServerUuidFor(
        transaction.categoryLocalUuid,
      );
      if (categoryUuid == null) {
        return null;
      }
    }

    return {
      'account': accountUuid,
      'destination': destinationUuid,
      'category': categoryUuid,
    };
  }

  Future<void> _pushCreate(TransactionModel transaction) async {
    final uuids = await _resolveUuids(transaction);
    if (uuids == null) {
      return;
    }
    final json = await _remote.create(
      transaction.toApiPayload(
        accountUuid: uuids['account']!,
        destinationAccountUuid: uuids['destination'],
        categoryUuid: uuids['category'],
      ),
    );
    await _local.markSynced(
      localUuid: transaction.localUuid,
      serverUuid: json['uuid'] as String,
    );
  }

  Future<void> _pushUpdate(TransactionModel transaction) async {
    final uuids = await _resolveUuids(transaction);
    if (uuids == null) {
      return;
    }
    await _remote.update(
      transaction.serverUuid!,
      transaction.toApiPayload(
        accountUuid: uuids['account']!,
        destinationAccountUuid: uuids['destination'],
        categoryUuid: uuids['category'],
      ),
    );
    await _local.markSynced(
      localUuid: transaction.localUuid,
      serverUuid: transaction.serverUuid!,
    );
  }

  Future<void> _pushDelete(TransactionModel transaction) async {
    await _remote.delete(transaction.serverUuid!);
    await _local.deleteHard(transaction.localUuid);
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

    final accountJson = json['account'] as Map<String, dynamic>?;
    final accountLocalUuid = await _local.accountLocalUuidFor(
      accountJson?['uuid'] as String?,
    );
    if (accountLocalUuid == null) {
      // The account hasn't been pulled locally yet — skip, we'll catch this
      // transaction on a later sync pass once accounts have synced down.
      return;
    }

    final destinationJson =
        json['destination_account'] as Map<String, dynamic>?;
    final categoryJson = json['category'] as Map<String, dynamic>?;

    final incoming = TransactionModel.fromApiJson(
      json,
      localUuid: existingLocalUuid ?? _local.newLocalUuid(),
      accountLocalUuid: accountLocalUuid,
      destinationAccountLocalUuid: await _local.accountLocalUuidFor(
        destinationJson?['uuid'] as String?,
      ),
      categoryLocalUuid: await _local.categoryLocalUuidFor(
        categoryJson?['uuid'] as String?,
      ),
    );
    // No `updated_at` on TransactionResource — see ReminderRepository.
    await _local.upsert(incoming);
  }

  void dispose() => unawaited(_changesController.close());
}
