import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/sync_query_helpers.dart';
import 'note_model.dart';

const _table = 'notes';

class NoteLocalDataSource {
  NoteLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  Future<List<NoteModel>> getAll({bool includeArchived = false}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    return rows.map(NoteModel.fromRow).toList();
  }

  Future<NoteModel?> getByLocalUuid(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : NoteModel.fromRow(rows.first);
  }

  String newLocalUuid() => _uuid.v4();

  Future<void> upsert(NoteModel note) async {
    final db = await _appDatabase.database;
    await db.insert(
      _table,
      note.toRow(),
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

  /// Rows never pushed at all (`pending_create` with no `server_uuid`) can
  /// just be dropped locally instead of round-tripping a delete request.
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

  /// `server_uuid`s currently known locally as fully-synced (used by
  /// [NoteRepository.pull] to prune rows deleted server-side).
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

  /// Resolves a category's *local* uuid to its *server* uuid, for the FK
  /// the note push payload needs. Returns null if the category hasn't
  /// synced yet — the repository then defers this note to the next pass.
  Future<String?> categoryServerUuidFor(String? categoryLocalUuid) async =>
      SyncQueryHelpers.serverUuidFor(
        await _appDatabase.database,
        'categories',
        categoryLocalUuid,
      );

  /// Resolves a category's *server* uuid (as returned nested in a pulled
  /// note) back to its local uuid.
  Future<String?> categoryLocalUuidFor(String? categoryServerUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        'categories',
        categoryServerUuid,
      );
}
