import '../../../core/storage/app_database.dart';

const reminderTypes = {
  'task': 'Tâche',
  'appointment': 'Rendez-vous',
  'birthday': 'Anniversaire',
  'medication': 'Médicament',
  'bill': 'Facture',
  'event': 'Événement',
  'other': 'Autre',
};

const reminderRecurrences = {
  'none': 'Aucune',
  'daily': 'Quotidienne',
  'weekly': 'Hebdomadaire',
  'monthly': 'Mensuelle',
  'yearly': 'Annuelle',
};

/// Mirrors `ReminderResource` + the offline sync columns from the
/// `reminders` table. `noteLocalUuid` is the local FK to an optional note
/// (resolved to the note's `server_uuid` — API field `note_uuid` — only at
/// push time, since the note may not have synced yet).
class ReminderModel {
  const ReminderModel({
    required this.localUuid,
    this.serverUuid,
    this.noteLocalUuid,
    this.categoryLocalUuid,
    required this.title,
    this.description,
    required this.dueAt,
    this.location,
    this.type = 'task',
    this.priority = 'normal',
    this.recurrence = 'none',
    this.isCompleted = false,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String? noteLocalUuid;
  final String? categoryLocalUuid;
  final String title;
  final String? description;
  final DateTime dueAt;
  final String? location;
  final String type;
  final String priority;
  final String recurrence;
  final bool isCompleted;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;
  bool get isOverdue => !isCompleted && dueAt.isBefore(DateTime.now());

  ReminderModel copyWith({
    String? noteLocalUuid,
    bool clearNote = false,
    String? categoryLocalUuid,
    bool clearCategory = false,
    String? title,
    String? description,
    DateTime? dueAt,
    String? location,
    String? type,
    String? priority,
    String? recurrence,
    bool? isCompleted,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => ReminderModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    noteLocalUuid: clearNote ? null : (noteLocalUuid ?? this.noteLocalUuid),
    categoryLocalUuid: clearCategory
        ? null
        : (categoryLocalUuid ?? this.categoryLocalUuid),
    title: title ?? this.title,
    description: description ?? this.description,
    dueAt: dueAt ?? this.dueAt,
    location: location ?? this.location,
    type: type ?? this.type,
    priority: priority ?? this.priority,
    recurrence: recurrence ?? this.recurrence,
    isCompleted: isCompleted ?? this.isCompleted,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory ReminderModel.fromRow(Map<String, Object?> row) => ReminderModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    noteLocalUuid: row['note_local_uuid'] as String?,
    categoryLocalUuid: row['category_local_uuid'] as String?,
    title: row['title']! as String,
    description: row['description'] as String?,
    dueAt: DateTime.parse(row['due_at']! as String),
    location: row['location'] as String?,
    type: row['type']! as String,
    priority: row['priority']! as String,
    recurrence: row['recurrence']! as String,
    isCompleted: (row['is_completed']! as int) == 1,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'note_local_uuid': noteLocalUuid,
    'category_local_uuid': categoryLocalUuid,
    'title': title,
    'description': description,
    'due_at': dueAt.toIso8601String(),
    'location': location,
    'type': type,
    'priority': priority,
    'recurrence': recurrence,
    'is_completed': isCompleted ? 1 : 0,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  /// [noteLocalUuid] is resolved separately by the repository (it needs a
  /// DB lookup from the API's nested `note.uuid` back to a local row).
  factory ReminderModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
    String? noteLocalUuid,
    String? categoryLocalUuid,
  }) => ReminderModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    noteLocalUuid: noteLocalUuid,
    categoryLocalUuid: categoryLocalUuid,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    dueAt: DateTime.parse(json['due_at'] as String),
    location: json['location'] as String?,
    type: json['type'] as String? ?? 'task',
    priority: json['priority'] as String? ?? 'normal',
    recurrence: json['recurrence'] as String? ?? 'none',
    isCompleted: json['is_completed'] as bool? ?? false,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  /// [noteUuid]/[categoryUuid] are the linked note/category's *server*
  /// uuids, resolved by the repository right before the request is sent.
  Map<String, dynamic> toApiPayload({String? noteUuid, String? categoryUuid}) =>
      {
        'note_uuid': noteUuid,
        'category_uuid': categoryUuid,
        'title': title,
        'description': description,
        'due_at': dueAt.toIso8601String(),
        'location': location,
        'type': type,
        'priority': priority,
        'recurrence': recurrence,
        'is_completed': isCompleted,
      };
}
