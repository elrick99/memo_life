import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/sync_query_helpers.dart';
import 'tag_model.dart';

const _table = 'tags';

class TagLocalDataSource {
  TagLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  Future<List<TagModel>> getAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, orderBy: 'name ASC');

    return rows.map(TagModel.fromRow).toList();
  }

  Future<TagModel?> getByLocalUuid(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : TagModel.fromRow(rows.first);
  }

  String newLocalUuid() => _uuid.v4();

  Future<void> upsert(TagModel tag) async {
    final db = await _appDatabase.database;
    await db.insert(
      _table,
      tag.toRow(),
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

  /// Resolves a tag's *local* uuid to its *server* uuid, for the note push
  /// payload. Returns null if the tag hasn't synced yet.
  Future<String?> serverUuidFor(String localUuid) async =>
      SyncQueryHelpers.serverUuidFor(
        await _appDatabase.database,
        _table,
        localUuid,
      );

  /// Resolves a tag's *server* uuid (as returned nested in a pulled note)
  /// back to its local uuid.
  Future<String?> localUuidForServer(String serverUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        _table,
        serverUuid,
      );
}
