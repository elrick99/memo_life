import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/sync_query_helpers.dart';
import 'attachment_model.dart';

const _table = 'attachments';

class AttachmentLocalDataSource {
  AttachmentLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;
  final _uuid = const Uuid();

  Future<List<AttachmentModel>> getFor({
    required String attachableType,
    required String attachableLocalUuid,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'attachable_type = ? AND attachable_local_uuid = ?',
      whereArgs: [attachableType, attachableLocalUuid],
      orderBy: 'updated_at ASC',
    );

    return rows.map(AttachmentModel.fromRow).toList();
  }

  Future<AttachmentModel?> getByLocalUuid(String localUuid) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : AttachmentModel.fromRow(rows.first);
  }

  String newLocalUuid() => _uuid.v4();

  Future<void> upsert(AttachmentModel attachment) async {
    final db = await _appDatabase.database;
    await db.insert(
      _table,
      attachment.toRow(),
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

  Future<void> setLocalFilePath({
    required String localUuid,
    required String localFilePath,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      _table,
      {'local_file_path': localFilePath},
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );
  }

  /// Attachments already known locally (any status) for a given parent, by
  /// their server uuid — used to reconcile the nested list a note/reminder
  /// pull comes back with, without touching not-yet-pushed local rows.
  Future<Set<String>> syncedServerUuidsFor({
    required String attachableType,
    required String attachableLocalUuid,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      columns: ['server_uuid'],
      where: 'attachable_type = ? AND attachable_local_uuid = ? AND sync_status = ? AND server_uuid IS NOT NULL',
      whereArgs: [attachableType, attachableLocalUuid, SyncStatus.synced],
    );

    return rows.map((row) => row['server_uuid']! as String).toSet();
  }

  Future<String?> localUuidForServerUuid(String serverUuid) async =>
      SyncQueryHelpers.localUuidFor(
        await _appDatabase.database,
        _table,
        serverUuid,
      );

  /// Resolves the parent note/reminder's *local* uuid to its *server*
  /// uuid — [attachableType] picks which table to look in.
  Future<String?> parentServerUuidFor({
    required String attachableType,
    required String attachableLocalUuid,
  }) async => SyncQueryHelpers.serverUuidFor(
    await _appDatabase.database,
    _parentTable(attachableType),
    attachableLocalUuid,
  );

  String _parentTable(String attachableType) =>
      attachableType == 'note' ? 'notes' : 'reminders';
}
