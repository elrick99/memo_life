import '../../../core/storage/app_database.dart';

/// Mirrors `AttachmentResource` + the offline sync columns from the
/// `attachments` table. Attachments are polymorphic like on the backend:
/// [attachableType] is `'note'` or `'reminder'`, [attachableLocalUuid] the
/// parent's local FK (resolved to its `server_uuid` at push time, same
/// pattern as `ReminderModel.noteLocalUuid`).
///
/// Unlike every other resource, attachments have no `GET` list endpoint —
/// the API only exposes nested create/show/delete under a note or reminder,
/// so a pulled attachment always arrives nested inside that parent's own
/// pull response, never through an independent index call. [localFilePath]
/// is therefore nullable: a freshly picked, not-yet-uploaded attachment
/// always has one (the local copy), while a pulled-from-server attachment
/// has none until [AttachmentRepository.downloadIfNeeded] fetches it.
class AttachmentModel {
  const AttachmentModel({
    required this.localUuid,
    this.serverUuid,
    required this.attachableType,
    required this.attachableLocalUuid,
    this.localFilePath,
    required this.filename,
    this.mimeType,
    this.size = 0,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pendingCreate,
  });

  final String localUuid;
  final String? serverUuid;
  final String attachableType;
  final String attachableLocalUuid;
  final String? localFilePath;
  final String filename;
  final String? mimeType;
  final int size;
  final DateTime updatedAt;
  final String syncStatus;

  bool get isSynced => syncStatus == SyncStatus.synced;
  bool get isDownloaded => localFilePath != null;
  bool get isImage => (mimeType ?? '').startsWith('image/');

  AttachmentModel copyWith({
    String? serverUuid,
    String? localFilePath,
    String? syncStatus,
  }) => AttachmentModel(
    localUuid: localUuid,
    serverUuid: serverUuid ?? this.serverUuid,
    attachableType: attachableType,
    attachableLocalUuid: attachableLocalUuid,
    localFilePath: localFilePath ?? this.localFilePath,
    filename: filename,
    mimeType: mimeType,
    size: size,
    updatedAt: updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  factory AttachmentModel.fromRow(Map<String, Object?> row) => AttachmentModel(
    localUuid: row['local_uuid']! as String,
    serverUuid: row['server_uuid'] as String?,
    attachableType: row['attachable_type']! as String,
    attachableLocalUuid: row['attachable_local_uuid']! as String,
    localFilePath: row['local_file_path'] as String?,
    filename: row['filename']! as String,
    mimeType: row['mime_type'] as String?,
    size: row['size']! as int,
    updatedAt: DateTime.parse(row['updated_at']! as String),
    syncStatus: row['sync_status']! as String,
  );

  Map<String, Object?> toRow() => {
    'local_uuid': localUuid,
    'server_uuid': serverUuid,
    'attachable_type': attachableType,
    'attachable_local_uuid': attachableLocalUuid,
    'local_file_path': localFilePath,
    'filename': filename,
    'mime_type': mimeType,
    'size': size,
    'updated_at': updatedAt.toIso8601String(),
    'sync_status': syncStatus,
  };

  /// Parses a nested `AttachmentResource` entry (from a note/reminder pull)
  /// into a fully-synced local row with no local file yet.
  factory AttachmentModel.fromApiJson(
    Map<String, dynamic> json, {
    required String localUuid,
    required String attachableType,
    required String attachableLocalUuid,
  }) => AttachmentModel(
    localUuid: localUuid,
    serverUuid: json['uuid'] as String,
    attachableType: attachableType,
    attachableLocalUuid: attachableLocalUuid,
    filename: json['filename'] as String? ?? '',
    mimeType: json['mime_type'] as String?,
    size: json['size'] as int? ?? 0,
    updatedAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
  );
}
