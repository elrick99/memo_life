import '../../../core/network/api_client.dart';

/// Thin wrapper over `CategoryController` (`index`/`store`/`destroy` only
/// — no update endpoint, and `index` is a flat, unpaginated list of system
/// + the current user's own categories).
class CategoryRemoteDataSource {
  CategoryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> index() async {
    final body = await _api.get('/categories');

    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final body = await _api.post('/categories', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String serverUuid) =>
      _api.delete('/categories/$serverUuid');
}
