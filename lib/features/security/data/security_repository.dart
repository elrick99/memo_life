import '../../auth/data/auth_user.dart';
import 'security_remote_data_source.dart';

/// Thin pass-through over [SecurityRemoteDataSource] — profile/password/2FA
/// changes are always online-only (no offline queue: there's nothing
/// meaningful to do with a stale password change), so this repository adds
/// no local persistence beyond what [SecurityRemoteDataSource] itself does.
class SecurityRepository {
  SecurityRepository(this._remote);

  final SecurityRemoteDataSource _remote;

  Future<AuthUser> updateProfile({
    required String name,
    required String email,
  }) => _remote.updateProfile(name: name, email: email);

  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) => _remote.updatePassword(
    currentPassword: currentPassword,
    password: password,
    passwordConfirmation: passwordConfirmation,
  );

  Future<TwoFactorSecret> enableTwoFactor() => _remote.enableTwoFactor();

  Future<List<String>> confirmTwoFactor(String code) =>
      _remote.confirmTwoFactor(code);

  Future<void> disableTwoFactor() => _remote.disableTwoFactor();

  Future<List<String>> recoveryCodes() => _remote.recoveryCodes();
}
