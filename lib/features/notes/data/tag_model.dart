import '../../../core/storage/app_database.dart';

/// Mirrors `TagResource` + the offline sync columns from the `tags` table.
/// Like categories, the API only has create/delete — no update endpoint.
class TagModel {
  const TagModel({
    required this.localUuid,
    this.serverUuid,
    required this.name,
    this.color,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String name;
  final String? color;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  factory TagModel.fromRow(Map<String, Object?> row) => TagModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    name: row['name']! as String,
    color: row['color'] as String?,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'name': name,
    'color': color,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory TagModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
  }) => TagModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    color: json['color'] as String?,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  Map<String, dynamic> toApiPayload() => {'name': name, 'color': color};
}
