import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../core/sync/connectivity_service.dart';
import 'auth_remote_data_source.dart';
import 'auth_user.dart';

/// Owns the session lifecycle: persisting the token + a cached user profile
/// (so the app can boot straight into the authenticated shell while
/// offline), and wiping the offline cache on logout.
class AuthRepository {
  AuthRepository({
    required this._remote,
    required this._tokenStorage,
    required this._connectivity,
    required this._database,
  });

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;
  final ConnectivityService _connectivity;
  final AppDatabase _database;

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final result = await _remote.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    await _persistSession(result);

    return result.user;
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final result = await _remote.login(email: email, password: password);
    await _persistSession(result);

    return result.user;
  }

  /// Refreshes the cached profile after an out-of-band update (e.g. the
  /// Profile screen), so the offline-restored session stays accurate.
  Future<void> updateCachedUser(AuthUser user) =>
      _tokenStorage.saveCachedUser(jsonEncode(user.toJson()));

  Future<bool> isGuest() => _tokenStorage.isGuest();

  Future<void> enterGuestMode() => _tokenStorage.setGuest(true);

  /// Called once a guest successfully registers/logs in for real: the
  /// session now has a token, so the guest flag no longer applies.
  Future<void> exitGuestMode() => _tokenStorage.setGuest(false);

  Future<void> logout() async {
    try {
      await _remote.logout();
    } on ApiException {
      // Best-effort: the token may already be invalid, or we're offline —
      // either way the local session still gets wiped below.
    }
    await _tokenStorage.clearSession();
    await _tokenStorage.setGuest(false);
    await _database.clearAll();
  }

  /// Called once at app boot. Prefers a fresh `/auth/me` when online (also
  /// refreshes the cached profile); falls back to the cached profile when
  /// offline or on a transient network error. A confirmed 401 clears the
  /// session outright.
  Future<AuthUser?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null) {
      return null;
    }

    if (await _connectivity.isOnline) {
      try {
        final user = await _remote.me();
        await _tokenStorage.saveCachedUser(jsonEncode(user.toJson()));

        return user;
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          await _tokenStorage.clearSession();

          return null;
        }
        // Fall through to the cached profile below.
      }
    }

    final cached = await _tokenStorage.readCachedUser();

    return cached == null
        ? null
        : AuthUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  }

  Future<void> _persistSession(AuthResult result) async {
    await _tokenStorage.saveToken(result.token);
    await _tokenStorage.saveCachedUser(jsonEncode(result.user.toJson()));
  }
}
