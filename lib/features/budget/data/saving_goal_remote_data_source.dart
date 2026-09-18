import '../../../core/network/api_client.dart';

class SavingGoalPage {
  const SavingGoalPage({required this.items, required this.lastPage});

  final List<Map<String, dynamic>> items;
  final int lastPage;
}

/// Thin wrapper over `apiResource('saving-goals', SavingGoalController::class)`.
class SavingGoalRemoteDataSource {
  SavingGoalRemoteDataSource(this._api);

  final ApiClient _api;

  Future<SavingGoalPage> index({int page = 1}) async {
    final body = await _api.get('/saving-goals', query: {'page': page});
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};

    return SavingGoalPage(
      items: (body['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final body = await _api.post('/saving-goals', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    final body = await _api.patch('/saving-goals/$serverUuid', data: payload);

    return body['data'] as Map<String, dynamic>;
  }

  Future<void> delete(String serverUuid) =>
      _api.delete('/saving-goals/$serverUuid');
}
