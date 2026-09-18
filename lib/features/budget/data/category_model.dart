import '../../../core/storage/app_database.dart';

const categoryTypes = {
  'expense': 'Dépense',
  'income': 'Revenu',
  'other': 'Autre',
  'note': 'Note',
  'reminder': 'Rappel',
};

/// Mirrors `CategoryResource` + the offline sync columns from the
/// `categories` table. Unlike the other budget resources, the API has no
/// update endpoint for categories — only create and delete.
class CategoryModel {
  const CategoryModel({
    required this.localUuid,
    this.serverUuid,
    required this.name,
    this.type = 'expense',
    this.isSystem = false,
    this.color,
    this.icon,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String name;
  final String type;
  final bool isSystem;
  final String? color;
  final String? icon;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  factory CategoryModel.fromRow(Map<String, Object?> row) => CategoryModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    name: row['name']! as String,
    type: row['type']! as String,
    isSystem: (row['is_system']! as int) == 1,
    color: row['color'] as String?,
    icon: row['icon'] as String?,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'name': name,
    'type': type,
    'is_system': isSystem ? 1 : 0,
    'color': color,
    'icon': icon,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory CategoryModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
  }) => CategoryModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'expense',
    isSystem: json['is_system'] as bool? ?? false,
    color: json['color'] as String?,
    icon: json['icon'] as String?,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  Map<String, dynamic> toApiPayload() => {
    'name': name,
    'type': type,
    'color': color,
    'icon': icon,
  };
}
