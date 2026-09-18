import '../../../core/network/api_client.dart';
import 'auth_user.dart';

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Thin wrapper over the `/auth/*` endpoints (`AuthController`). No local
/// persistence here — that's [AuthRepository]'s job.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String deviceName = 'mobile',
  }) async {
    final body = await _api.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': deviceName,
      },
    );

    return _parseAuthResult(body['data'] as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    String deviceName = 'mobile',
  }) async {
    final body = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    );

    return _parseAuthResult(body['data'] as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final body = await _api.get('/auth/me');

    return AuthUser.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> logout() => _api.post('/auth/logout');

  AuthResult _parseAuthResult(Map<String, dynamic> data) => AuthResult(
    token: data['token'] as String,
    user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
  );
}
