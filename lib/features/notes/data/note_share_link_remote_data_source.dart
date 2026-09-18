import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'note_share_link_model.dart';

/// Thin wrapper over `Api\V1\NoteShareLinkController`.
class NoteShareLinkRemoteDataSource {
  NoteShareLinkRemoteDataSource(this._api);

  final ApiClient _api;

  /// Returns null if no link is currently active (a 404 from the backend).
  Future<NoteShareLinkModel?> current(String noteServerUuid) async {
    try {
      final body = await _api.get('/notes/$noteServerUuid/share-link');

      return NoteShareLinkModel.fromJson(body['data'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Creates a new link, revoking any previous one — the only call that
  /// returns a usable `url`.
  Future<NoteShareLinkModel> create(String noteServerUuid) async {
    final body = await _api.post('/notes/$noteServerUuid/share-link');

    return NoteShareLinkModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> revoke(String noteServerUuid) =>
      _api.delete('/notes/$noteServerUuid/share-link');
}
