import 'package:local_auth/local_auth.dart';

/// Thin wrapper over [LocalAuthentication] gating access to a locked
/// note's content — biometrics if enrolled, falling back to the device's
/// own PIN/pattern/password (`biometricOnly: false`).
class NoteLockService {
  NoteLockService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> authenticate() async {
    if (!await _auth.isDeviceSupported()) {
      // No device lock configured at all — nothing to gate against, so
      // don't strand the user in front of a note they can never open.
      return true;
    }
    try {
      return await _auth.authenticate(
        localizedReason: 'Authentifiez-vous pour ouvrir cette note',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } on Exception {
      return false;
    }
  }
}
