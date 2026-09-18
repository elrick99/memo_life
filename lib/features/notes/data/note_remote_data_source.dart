import '../../../core/network/api_client.dart';

class NotePage {
  const NotePage({required this.items, required this.lastPage});

  final List<Map<String, dynamic>> items;
  final int lastPage;
}

/// Thin wrapper over `apiResource('notes', NoteController::class)`.
class NoteRemoteDataSource {
  NoteRemoteDataSource(this._api);

  final ApiClient _api;

  Future<NotePage> index({int page = 1}) async {
    final body = await _api.get('/notes', query: {'page': page});
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};

    return NotePage(
      items: (body['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<Map<String, dynamic>> show(String serverUuid) async {
    final body = await _api.get('/notes/$serverUuid');

    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final body = await _api.post('/notes', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    final body = await _api.patch('/notes/$serverUuid', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String serverUuid) => _api.delete('/notes/$serverUuid');
}
