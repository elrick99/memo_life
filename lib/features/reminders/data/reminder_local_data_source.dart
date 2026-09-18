import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/sync_query_helpers.dart';
import 'reminder_model.dart';

const _table = 'reminders';

class ReminderLocalDataSource {
  ReminderLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  Future<List<ReminderModel>> getAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, orderBy: 'due_at ASC');

    return rows.map(ReminderModel.fromRow).toList();
  }

  Future<ReminderModel?> getByLocalUuid(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : ReminderModel.fromRow(rows.first);
  }

  String newLocalUuid() => _uuid.v4();

  Future<void> upsert(ReminderModel reminder) async {
    final db = await _appDatabase.database;
    await db.insert(
      _table,
      reminder.toRow(),
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

  /// Resolves a note's *local* uuid to its *server* uuid, for the FK the
  /// reminder push payload needs. Returns null if the note hasn't synced
  /// yet — the repository then defers this reminder to the next sync pass.
  Future<String?> noteServerUuidFor(String? noteLocalUuid) async =>
      SyncQueryHelpers.serverUuidFor(
        await _appDatabase.database,
        'notes',
        noteLocalUuid,
      );

  /// Resolves a note's *server* uuid (as returned nested in a pulled
  /// reminder) back to its local uuid.
  Future<String?> noteLocalUuidFor(String? noteServerUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        'notes',
        noteServerUuid,
      );

  /// Same as [noteServerUuidFor]/[noteLocalUuidFor], for the reminder's
  /// optional category FK.
  Future<String?> categoryServerUuidFor(String? categoryLocalUuid) async =>
      SyncQueryHelpers.serverUuidFor(
        await _appDatabase.database,
        'categories',
        categoryLocalUuid,
      );

  Future<String?> categoryLocalUuidFor(String? categoryServerUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        'categories',
        categoryServerUuid,
      );
}
