import '../../../core/storage/app_database.dart';
import '../../../core/utils/json_parsing.dart';

const accountTypes = {
  'cash': 'Espèces',
  'bank': 'Banque',
  'orange_money': 'Orange Money',
  'mtn_money': 'MTN Money',
  'moov_money': 'Moov Money',
  'other': 'Autre',
};

/// Mirrors `AccountResource` + the offline sync columns from the
/// `accounts` table.
class AccountModel {
  const AccountModel({
    required this.localUuid,
    this.serverUuid,
    required this.name,
    this.type = 'cash',
    this.balance = 0,
    this.currency = 'XOF',
    this.icon,
    this.color,
    this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final String? icon;
  final String? color;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  AccountModel copyWith({
    String? name,
    String? type,
    double? balance,
    String? currency,
    String? icon,
    String? color,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => AccountModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    name: name ?? this.name,
    type: type ?? this.type,
    balance: balance ?? this.balance,
    currency: currency ?? this.currency,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory AccountModel.fromRow(Map<String, Object?> row) => AccountModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    name: row['name']! as String,
    type: row['type']! as String,
    balance: (row['balance']! as num).toDouble(),
    currency: row['currency']! as String,
    icon: row['icon'] as String?,
    color: row['color'] as String?,
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at']! as String)
        : null,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'name': name,
    'type': type,
    'balance': balance,
    'currency': currency,
    'icon': icon,
    'color': color,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory AccountModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
  }) => AccountModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'cash',
    balance: parseApiDecimal(json['balance']),
    currency: json['currency'] as String? ?? 'XOF',
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  Map<String, dynamic> toApiPayload() => {
    'name': name,
    'type': type,
    'balance': balance,
    'currency': currency,
    'icon': icon,
    'color': color,
  };
}
