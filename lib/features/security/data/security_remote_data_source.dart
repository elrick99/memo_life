import '../../../core/network/api_client.dart';
import '../../auth/data/auth_user.dart';

class TwoFactorSecret {
  const TwoFactorSecret({required this.url, required this.secretKey});

  /// The raw `otpauth://` URI — rendered client-side as a QR code (no need
  /// to fetch/display the server's SVG).
  final String url;
  final String secretKey;
}

/// Thin wrapper over `Api\V1\ProfileController` and `Api\V1\SecurityController`.
class SecurityRemoteDataSource {
  SecurityRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) async {
    final body = await _api.put(
      '/profile',
      data: {'name': name, 'email': email},
    );

    return AuthUser.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) => _api.put(
    '/security/password',
    data: {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    },
  );

  Future<TwoFactorSecret> enableTwoFactor() async {
    final body = await _api.post('/security/two-factor');
    final data = body['data'] as Map<String, dynamic>;

    return TwoFactorSecret(
      url: data['url'] as String,
      secretKey: data['secret_key'] as String,
    );
  }

  Future<List<String>> confirmTwoFactor(String code) async {
    final body = await _api.post(
      '/security/two-factor/confirm',
      data: {'code': code},
    );
    final data = body['data'] as Map<String, dynamic>;

    return (data['recovery_codes'] as List<dynamic>).cast<String>();
  }

  Future<void> disableTwoFactor() => _api.delete('/security/two-factor');

  Future<List<String>> recoveryCodes() async {
    final body = await _api.get('/security/two-factor/recovery-codes');

    return (body['data'] as List<dynamic>).cast<String>();
  }
}
