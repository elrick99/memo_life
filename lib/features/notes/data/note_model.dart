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
    this.tagLocalUuids = const [],
    required this.title,
    this.content,
    this.contentFormat = 'plain',
    this.checklist = const [],
    this.priority = 'normal',
    this.color,
    this.colorMode = 'automatic',
    this.isArchived = false,
    this.isPinned = false,
    this.isLocked = false,
    this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String? categoryLocalUuid;
  final List<String> tagLocalUuids;
  final String title;
  final String? content;
  final String contentFormat;
  final List<ChecklistItem> checklist;
  final String priority;
  final String? color;
  final String colorMode;
  final bool isArchived;
  final bool isPinned;
  final bool isLocked;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;

  int get checklistCompletionPercent => checklist.isEmpty
      ? 0
      : ((checklist.where((item) => item.completed).length / checklist.length) *
                100)
            .round();

  NoteModel copyWith({
    String? categoryLocalUuid,
    bool clearCategory = false,
    List<String>? tagLocalUuids,
    String? title,
    String? content,
    bool clearContent = false,
    String? contentFormat,
    List<ChecklistItem>? checklist,
    String? priority,
    String? color,
    String? colorMode,
    bool? isArchived,
    bool? isPinned,
    bool? isLocked,
    DateTime? updatedAt,
    String? syncStatus,
    String? serverUuid,
  }) => NoteModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    categoryLocalUuid: clearCategory
        ? null
        : (categoryLocalUuid ?? this.categoryLocalUuid),
    tagLocalUuids: tagLocalUuids ?? this.tagLocalUuids,
    title: title ?? this.title,
    content: clearContent ? null : (content ?? this.content),
    contentFormat: contentFormat ?? this.contentFormat,
    checklist: checklist ?? this.checklist,
    priority: priority ?? this.priority,
    color: color ?? this.color,
    colorMode: colorMode ?? this.colorMode,
    isArchived: isArchived ?? this.isArchived,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory NoteModel.fromRow(Map<String, Object?> row) => NoteModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    categoryLocalUuid: row['category_local_uuid'] as String?,
    tagLocalUuids: _decodeTagLocalUuids(row['tag_local_uuids'] as String?),
    title: row['title']! as String,
    content: row['content'] as String?,
    contentFormat: row['content_format']! as String,
    checklist: _decodeChecklist(row['checklist'] as String?),
    priority: row['priority']! as String,
    color: row['color'] as String?,
    colorMode: row['color_mode']! as String,
    isArchived: (row['is_archived']! as int) == 1,
    isPinned: (row['is_pinned']! as int) == 1,
    isLocked: (row['is_locked']! as int) == 1,
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
    'tag_local_uuids': tagLocalUuids.isEmpty ? null : jsonEncode(tagLocalUuids),
    'title': title,
    'content': content,
    'content_format': contentFormat,
    'checklist': checklist.isEmpty
        ? null
        : jsonEncode(checklist.map((item) => item.toJson()).toList()),
    'priority': priority,
    'color': color,
    'color_mode': colorMode,
    'is_archived': isArchived ? 1 : 0,
    'is_pinned': isPinned ? 1 : 0,
    'is_locked': isLocked ? 1 : 0,
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
    List<String> tagLocalUuids = const [],
  }) => NoteModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    categoryLocalUuid: categoryLocalUuid,
    tagLocalUuids: tagLocalUuids,
    title: json['title'] as String? ?? '',
    content: json['content'] as String?,
    contentFormat: json['content_format'] as String? ?? 'plain',
    checklist: _decodeChecklistFromApi(json['checklist']),
    priority: json['priority'] as String? ?? 'normal',
    color: json['color'] as String?,
    colorMode: json['color_mode'] as String? ?? 'automatic',
    isArchived: json['is_archived'] as bool? ?? false,
    isPinned: json['is_pinned'] as bool? ?? false,
    isLocked: json['is_locked'] as bool? ?? false,
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
  /// [categoryUuid]/[tagUuids] are the linked category/tags' *server*
  /// uuids, resolved by the repository right before the request is sent.
  Map<String, dynamic> toApiPayload({
    String? categoryUuid,
    List<String>? tagUuids,
  }) => {
    'category_uuid': categoryUuid,
    'tag_uuids': tagUuids ?? const [],
    'title': title,
    'content': content,
    'content_format': contentFormat,
    'checklist': checklist.isEmpty
        ? null
        : checklist.map((item) => item.toJson()).toList(),
    'priority': priority,
    'color': color,
    'color_mode': colorMode,
    'is_archived': isArchived,
    'is_pinned': isPinned,
    'is_locked': isLocked,
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

  static List<String> _decodeTagLocalUuids(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return (jsonDecode(raw) as List<dynamic>).cast<String>();
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
