/// App-wide runtime configuration.
///
/// [apiBaseUrl] points at the Laravel API (`routes/api.php`, prefix `v1`).
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
///
/// Defaults (when not overridden) assume `php artisan serve` on the host
/// machine at port 8000:
///  - Android emulator: 10.0.2.2 is the host loopback alias (the default).
///  - iOS simulator: 127.0.0.1 reaches the host directly — pass
///    --dart-define=API_DEFAULT_HOST=http://127.0.0.1:8000.
///  - Physical device (either platform): must pass --dart-define=API_BASE_URL
///    pointing at the host machine's LAN IP (e.g. http://192.168.1.10:8000/api/v1).
class AppConfig {
  const AppConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) {
      return _override;
    }

    return '${_defaultHost()}/api/v1';
  }

  static String _defaultHost() {
    // Platform-specific defaults are resolved lazily via dart:io only when
    // no override is supplied, so web builds (no dart:io) still work when
    // API_BASE_URL is always passed there.
    return const String.fromEnvironment(
      'API_DEFAULT_HOST',
      defaultValue: 'http://10.0.2.2:8000',
    );
  }

  /// Reverb (WebSocket) connection details for live note collaboration.
  /// Defaults track this project's local `.env` (`REVERB_*`) so a fresh
  /// checkout works against `php artisan reverb:start` out of the box; every
  /// value can be overridden the same way as [apiBaseUrl] for other
  /// environments.
  static String get reverbHost =>
      const String.fromEnvironment('REVERB_HOST', defaultValue: '10.0.2.2');

  static int get reverbPort =>
      const int.fromEnvironment('REVERB_PORT', defaultValue: 8080);

  static String get reverbAppKey => const String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'f5734a0c7bc51f453bf5d562413ecc65',
  );

  static bool get reverbUseTLS =>
      const bool.fromEnvironment('REVERB_USE_TLS');
}
