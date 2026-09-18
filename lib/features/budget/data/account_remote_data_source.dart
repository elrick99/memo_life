import '../../../core/network/api_client.dart';

class AccountPage {
  const AccountPage({required this.items, required this.lastPage});

  final List<Map<String, dynamic>> items;
  final int lastPage;
}

/// Thin wrapper over `apiResource('accounts', AccountController::class)`.
class AccountRemoteDataSource {
  AccountRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AccountPage> index({int page = 1}) async {
    final body = await _api.get('/accounts', query: {'page': page});
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};

    return AccountPage(
      items: (body['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final body = await _api.post('/accounts', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    final body = await _api.patch('/accounts/$serverUuid', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String serverUuid) =>
      _api.delete('/accounts/$serverUuid');
}
