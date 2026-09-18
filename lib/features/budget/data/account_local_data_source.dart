import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/sync_query_helpers.dart';
import 'account_model.dart';

const _table = 'accounts';

class AccountLocalDataSource {
  AccountLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  Future<List<AccountModel>> getAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, orderBy: 'created_at DESC');

    return rows.map(AccountModel.fromRow).toList();
  }

  Future<AccountModel?> getByLocalUuid(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : AccountModel.fromRow(rows.first);
  }

  String newLocalUuid() => _uuid.v4();

  Future<void> upsert(AccountModel account) async {
    final db = await _appDatabase.database;
    await db.insert(
      _table,
      account.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markPendingDelete(String localUuid) async {
    final db = await _appDatabase.database;
    await db.update(
      _table,
      {
        'sync_status': SyncStatus.pendingDelete,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  Future<void> deleteHard(String localUuid) async {
    final db = await _appDatabase.database;
    await db.delete(_table, where: 'local_uuid = ?', whereArgs: [localUuid]);
  }

  /// Adjusts the cached balance for immediate UI feedback when a
  /// transaction is created/edited/deleted offline — deliberately *not*
  /// marked `pending_update`, since the balance is server-computed
  /// (`RecordTransaction`) and must never itself be pushed; the next
  /// successful pull overwrites this optimistic value with the real one.
  Future<void> adjustBalanceLocally(String localUuid, double delta) async {
    final db = await _appDatabase.database;
    await db.rawUpdate(
      'UPDATE $_table SET balance = balance + ? WHERE local_uuid = ?',
      [delta, localUuid],
    );
  }

  Future<bool> hasTransactions(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'transactions',
      where: 'account_local_uuid = ? OR destination_account_local_uuid = ?',
      whereArgs: [localUuid, localUuid],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> pendingRows() async =>
      SyncQueryHelpers.pendingRows(await _appDatabase.database, _table);

  Future<void> markSynced({
    required String localUuid,
    required String serverUuid,
  }) async => SyncQueryHelpers.markSynced(
    await _appDatabase.database,
    _table,
    localUuid: localUuid,
    serverUuid: serverUuid,
  );

  Future<String?> localUuidForServerUuid(String serverUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        _table,
        serverUuid,
      );

  Future<Set<String>> syncedServerUuids() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      columns: ['server_uuid'],
      where: 'sync_status = ? AND server_uuid IS NOT NULL',
      whereArgs: [SyncStatus.synced],
    );

    return rows.map((row) => row['server_uuid']! as String).toSet();
  }
}
