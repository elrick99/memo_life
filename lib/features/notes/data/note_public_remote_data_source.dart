import '../../../core/network/api_client.dart';
import 'checklist_item.dart';

class NotePublicView {
  const NotePublicView({
    required this.title,
    required this.content,
    required this.contentFormat,
    required this.checklist,
  });

  factory NotePublicView.fromJson(Map<String, dynamic> json) => NotePublicView(
    title: json['title'] as String?,
    content: json['content'] as String?,
    contentFormat: json['content_format'] as String? ?? 'plain',
    checklist: (json['checklist'] as List<dynamic>? ?? const [])
        .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final String? title;
  final String? content;
  final String contentFormat;
  final List<ChecklistItem> checklist;
}

/// Thin wrapper over the unauthenticated `NotePublicController` — backs the
/// `/notes/shared/{token}` deep link viewer, reachable with or without an
/// account (see `app.dart`'s router redirect exemption for that route).
class NotePublicRemoteDataSource {
  NotePublicRemoteDataSource(this._api);

  final ApiClient _api;

  Future<NotePublicView> show(String token) async {
    final body = await _api.get('/notes/public/$token');

    return NotePublicView.fromJson(body['data'] as Map<String, dynamic>);
  }
}
