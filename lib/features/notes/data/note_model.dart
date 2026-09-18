import 'dart:convert';

import '../../../core/storage/app_database.dart';
import 'checklist_item.dart';

/// Mirrors `NoteResource` + the offline sync columns from the `notes`
/// table (see [AppDatabase]). `localUuid` is the stable local identity;
/// `serverUuid` is null until the note is first pushed.
class NoteModel {
  const NoteModel({
    required this.localUuid,
    this.serverUuid,
    this.categoryLocalUuid,
    required this.title,
    this.content,
    this.checklist = const [],
    this.priority = 'normal',
    this.color,
    this.colorMode = 'automatic',
    this.isArchived = false,
    this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String? categoryLocalUuid;
  final String title;
  final String? content;
  final List<ChecklistItem> checklist;
  final String priority;
  final String? color;
  final String colorMode;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  NoteModel copyWith({
    String? categoryLocalUuid,
    bool clearCategory = false,
    String? title,
    String? content,
    bool clearContent = false,
    List<ChecklistItem>? checklist,
    String? priority,
    String? color,
    String? colorMode,
    bool? isArchived,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => NoteModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    categoryLocalUuid: clearCategory
        ? null
        : (categoryLocalUuid ?? this.categoryLocalUuid),
    title: title ?? this.title,
    content: clearContent ? null : (content ?? this.content),
    checklist: checklist ?? this.checklist,
    priority: priority ?? this.priority,
    color: color ?? this.color,
    colorMode: colorMode ?? this.colorMode,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory NoteModel.fromRow(Map<String, Object?> row) => NoteModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    categoryLocalUuid: row['category_local_uuid'] as String?,
    title: row['title']! as String,
    content: row['content'] as String?,
    checklist: _decodeChecklist(row['checklist'] as String?),
    priority: row['priority']! as String,
    color: row['color'] as String?,
    colorMode: row['color_mode']! as String,
    isArchived: (row['is_archived']! as int) == 1,
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at']! as String)
        : null,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'category_local_uuid': categoryLocalUuid,
    'title': title,
    'content': content,
    'checklist': checklist.isEmpty
        ? null
        : jsonEncode(checklist.map((item) => item.toJson()).toList()),
    'priority': priority,
    'color': color,
    'color_mode': colorMode,
    'is_archived': isArchived ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  /// Parses a `NoteResource` payload from the API into a fully-synced local
  /// row. [localUuid] is either the row's existing local identity (on
  /// update-pull) or a freshly generated one (first time we see this
  /// server record).
  factory NoteModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
    String? categoryLocalUuid,
  }) => NoteModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    categoryLocalUuid: categoryLocalUuid,
    title: json['title'] as String? ?? '',
    content: json['content'] as String?,
    checklist: _decodeChecklistFromApi(json['checklist']),
    priority: json['priority'] as String? ?? 'normal',
    color: json['color'] as String?,
    colorMode: json['color_mode'] as String? ?? 'automatic',
    isArchived: json['is_archived'] as bool? ?? false,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.now(),
    syncStatus: SyncStatus.synced,
  );

  /// Payload shape accepted by both `StoreNoteRequest` and
  /// `UpdateNoteRequest` — the server treats every field as optional on
  /// update, so the same builder works for create and update.
  /// [categoryUuid] is the linked category's *server* uuid, resolved by
  /// the repository right before the request is sent.
  Map<String, dynamic> toApiPayload({String? categoryUuid}) => {
    'category_uuid': categoryUuid,
    'title': title,
    'content': content,
    'checklist': checklist.isEmpty
        ? null
        : checklist.map((item) => item.toJson()).toList(),
    'priority': priority,
    'color': color,
    'color_mode': colorMode,
    'is_archived': isArchived,
  };

  static List<ChecklistItem> _decodeChecklist(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static List<ChecklistItem> _decodeChecklistFromApi(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    return raw
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
