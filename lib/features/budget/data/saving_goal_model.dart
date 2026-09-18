import '../../../core/storage/app_database.dart';
import '../../../core/utils/json_parsing.dart';

/// Mirrors `SavingGoalResource` + the offline sync columns. `progress` is
/// computed client-side (server computes it too, but doesn't send
/// timestamps back for us to reconcile against, so we derive it the same
/// way locally for immediate UI feedback on unsynced changes).
class SavingGoalModel {
  const SavingGoalModel({
    required this.localUuid,
    this.serverUuid,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.color,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String? color;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;
  double get progress => targetAmount <= 0
      ? 0
      : (currentAmount / targetAmount).clamp(0, 1).toDouble();

  SavingGoalModel copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? color,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => SavingGoalModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    name: name ?? this.name,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
    color: color ?? this.color,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory SavingGoalModel.fromRow(Map<String, Object?> row) => SavingGoalModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    name: row['name']! as String,
    targetAmount: (row['target_amount']! as num).toDouble(),
    currentAmount: (row['current_amount']! as num).toDouble(),
    targetDate: row['target_date'] != null
        ? DateTime.parse(row['target_date']! as String)
        : null,
    color: row['color'] as String?,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'name': name,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'target_date': targetDate?.toIso8601String(),
    'color': color,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  factory SavingGoalModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
  }) => SavingGoalModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    targetAmount: parseApiDecimal(json['target_amount']),
    currentAmount: parseApiDecimal(json['current_amount']),
    targetDate: json['target_date'] != null
        ? DateTime.parse(json['target_date'] as String)
        : null,
    color: json['color'] as String?,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  Map<String, dynamic> toApiPayload() => {
    'name': name,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'target_date': targetDate?.toIso8601String().split('T').first,
    'color': color,
  };
}
