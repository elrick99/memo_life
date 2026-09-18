import '../../../core/network/api_client.dart';

/// Thin wrapper over `TagController` (`index`/`store`/`destroy` only — no
/// update endpoint, `index` is a flat, unpaginated list of the current
/// user's own tags).
class TagRemoteDataSource {
  TagRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> index() async {
    final body = await _api.get('/tags');

    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final body = await _api.post('/tags', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String serverUuid) => _api.delete('/tags/$serverUuid');
}
