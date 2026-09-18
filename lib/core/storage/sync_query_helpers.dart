import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Small shared queries every [Syncable] repository's push/pull uses —
/// deliberately thin: the interesting per-feature logic (payload shape,
/// FK resolution) stays in each repository, not here.
class SyncQueryHelpers {
  const SyncQueryHelpers._();

  static Future<List<Map<String, Object?>>> pendingRows(
    Database db,
    String table,
  ) => db.query(
    table,
    where: 'sync_status != ?',
    whereArgs: [SyncStatus.synced],
  );

  static Future<void> markSynced(
    Database db,
    String table, {
    required String localUuid,
    required String serverUuid,
  }) => db.update(
    table,
    {'server_uuid': serverUuid, 'sync_status': SyncStatus.synced},
    where: 'local_uuid = ?',
    whereArgs: [localUuid],
  );

  static Future<void> deleteLocal(
    Database db,
    String table,
    String localUuid,
  ) => db.delete(table, where: 'local_uuid = ?', whereArgs: [localUuid]);

  /// Server uuid for a locally-known row, resolving a `*_local_uuid` FK to
  /// the value the API expects (`*_uuid`). Returns null if the referenced
  /// row hasn't been pushed yet — callers should skip/defer in that case.
  static Future<String?> serverUuidFor(
    Database db,
    String table,
    String? localUuid,
  ) async {
    if (localUuid == null) {
      return null;
    }
    final rows = await db.query(
      table,
      columns: ['server_uuid'],
      where: 'local_uuid = ?',
      whereArgs: [localUuid],
    );

    return rows.isEmpty ? null : rows.first['server_uuid'] as String?;
  }

  /// Local uuid for a row identified by its server uuid — used when
  /// reconciling a pulled record's relationships back to local FKs.
  static Future<String?> localUuidFor(
    Database db,
    String table,
    String? serverUuid,
  ) async {
    if (serverUuid == null) {
      return null;
    }
    final rows = await db.query(
      table,
      columns: ['local_uuid'],
      where: 'server_uuid = ?',
      whereArgs: [serverUuid],
    );

    return rows.isEmpty ? null : rows.first['local_uuid'] as String?;
  }
}
