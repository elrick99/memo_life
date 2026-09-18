import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token outside sqflite (encrypted keystore /
/// keychain), separate from the offline cache so a device wipe of the app's
/// SQL database never leaks a live session token.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _guestKey = 'is_guest';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  /// Cached JSON of the last-known authenticated user, so the app can
  /// restore a session while offline (no `/auth/me` call possible yet).
  Future<String?> readCachedUser() => _storage.read(key: _userKey);

  Future<void> saveCachedUser(String userJson) =>
      _storage.write(key: _userKey, value: userJson);

  Future<void> clearSession() => Future.wait([
    _storage.delete(key: _tokenKey),
    _storage.delete(key: _userKey),
  ]);

  /// Whether the app is in guest mode — no account, no token, everything
  /// local-only. Kept separate from [clearSession] since entering guest
  /// mode deliberately has no token to begin with.
  Future<bool> isGuest() async =>
      (await _storage.read(key: _guestKey)) == 'true';

  Future<void> setGuest(bool value) => value
      ? _storage.write(key: _guestKey, value: 'true')
      : _storage.delete(key: _guestKey);
}
