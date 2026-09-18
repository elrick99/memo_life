import '../../../core/storage/app_database.dart';
import '../../../core/utils/json_parsing.dart';

const transactionTypes = {
  'expense': 'Dépense',
  'income': 'Revenu',
  'transfer': 'Virement',
};

/// Mirrors `TransactionResource` + the offline sync columns. Three FKs,
/// all pointing at *local* uuids until push time:
///  - `accountLocalUuid` (required — a transaction always belongs to an
///    account, so a push is deferred entirely until this resolves).
///  - `destinationAccountLocalUuid` (transfers only).
///  - `categoryLocalUuid` (optional).
class TransactionModel {
  const TransactionModel({
    required this.localUuid,
    this.serverUuid,
    required this.accountLocalUuid,
    this.destinationAccountLocalUuid,
    this.categoryLocalUuid,
    this.type = 'expense',
    required this.amount,
    required this.occurredAt,
    this.description,
    this.attachmentPath,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String accountLocalUuid;
  final String? destinationAccountLocalUuid;
  final String? categoryLocalUuid;
  final String type;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String? attachmentPath;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  TransactionModel copyWith({
    String? accountLocalUuid,
    String? destinationAccountLocalUuid,
    bool clearDestinationAccount = false,
    String? categoryLocalUuid,
    bool clearCategory = false,
    String? type,
    double? amount,
    DateTime? occurredAt,
    String? description,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => TransactionModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    accountLocalUuid: accountLocalUuid ?? this.accountLocalUuid,
    destinationAccountLocalUuid: clearDestinationAccount
        ? null
        : (destinationAccountLocalUuid ?? this.destinationAccountLocalUuid),
    categoryLocalUuid: clearCategory
        ? null
        : (categoryLocalUuid ?? this.categoryLocalUuid),
    type: type ?? this.type,
    amount: amount ?? this.amount,
    occurredAt: occurredAt ?? this.occurredAt,
    description: description ?? this.description,
    attachmentPath: attachmentPath,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory TransactionModel.fromRow(Map<String, Object?> row) =>
      TransactionModel(
        localUuid: row['local_uuid']! as String,
        serverUuid: row['server_uuid'] as String?,
        accountLocalUuid: row['account_local_uuid']! as String,
        destinationAccountLocalUuid:
            row['destination_account_local_uuid'] as String?,
        categoryLocalUuid: row['category_local_uuid'] as String?,
        type: row['type']! as String,
        amount: (row['amount']! as num).toDouble(),
        occurredAt: DateTime.parse(row['occurred_at']! as String),
        description: row['description'] as String?,
        attachmentPath: row['attachment_path'] as String?,
        updatedAt: DateTime.parse(row['updated_at']! as String),
        syncStatus: row['sync_status']! as String,
      );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'account_local_uuid': accountLocalUuid,
    'destination_account_local_uuid': destinationAccountLocalUuid,
    'category_local_uuid': categoryLocalUuid,
    'type': type,
    'amount': amount,
    'occurred_at': occurredAt.toIso8601String(),
    'description': description,
    'attachment_path': attachmentPath,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory TransactionModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
    required String accountLocalUuid,
    String? destinationAccountLocalUuid,
    String? categoryLocalUuid,
  }) => TransactionModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    accountLocalUuid: accountLocalUuid,
    destinationAccountLocalUuid: destinationAccountLocalUuid,
    categoryLocalUuid: categoryLocalUuid,
    type: json['type'] as String? ?? 'expense',
    amount: parseApiDecimal(json['amount']),
    occurredAt: DateTime.parse(json['occurred_at'] as String),
    description: json['description'] as String?,
    attachmentPath: json['attachment_path'] as String?,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  /// uuids are resolved by the repository right before the request is sent.
  Map<String, dynamic> toApiPayload({
    required String accountUuid,
    String? destinationAccountUuid,
    String? categoryUuid,
  }) => {
    'account_uuid': accountUuid,
    'destination_account_uuid': destinationAccountUuid,
    'category_uuid': categoryUuid,
    'type': type,
    'amount': amount,
    'occurred_at': occurredAt.toIso8601String(),
    'description': description,
    'attachment_path': attachmentPath,
  };
}
