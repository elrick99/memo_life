import '../../../core/network/api_client.dart';
import 'checklist_item.dart';

class NoteRealtimeUpdate {
  const NoteRealtimeUpdate({
    required this.content,
    required this.checklist,
    required this.updatedAt,
  });

  factory NoteRealtimeUpdate.fromJson(Map<String, dynamic> json) =>
      NoteRealtimeUpdate(
        content: json['content'] as String?,
        checklist: (json['checklist'] as List<dynamic>? ?? const [])
            .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  final String? content;
  final List<ChecklistItem> checklist;
  final DateTime updatedAt;
}

/// Thin wrapper over `Api\V1\NoteRealtimeController::updateContent` — the
/// debounced content push a note editor makes while collaborators are live
/// on the note's presence channel. A `409` (conflict — someone else's edit
/// landed first) surfaces as an [ApiException]; the caller re-fetches the
/// note via [NoteRemoteDataSource.show] to recover the current server
/// content, since the exception itself doesn't carry the response body.
class NoteRealtimeRemoteDataSource {
  NoteRealtimeRemoteDataSource(this._api);

  final ApiClient _api;

  Future<NoteRealtimeUpdate> push({
    required String noteServerUuid,
    required String? content,
    required List<ChecklistItem> checklist,
    required DateTime lastKnownUpdatedAt,
  }) async {
    final body = await _api.post(
      '/notes/$noteServerUuid/realtime',
      data: {
        'content': content,
        'checklist': checklist.isEmpty
            ? null
            : checklist.map((item) => item.toJson()).toList(),
        'updated_at': lastKnownUpdatedAt.toIso8601String(),
      },
    );

    return NoteRealtimeUpdate.fromJson(body['data'] as Map<String, dynamic>);
  }
}
