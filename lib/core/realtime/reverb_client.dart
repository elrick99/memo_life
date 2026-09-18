import 'package:laravel_reverb/laravel_reverb.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';

/// App-wide Reverb client for live note collaboration.
///
/// Authorized against this app's own Sanctum-protected broadcasting auth
/// route (`BroadcastAuthController`, `POST /notes` base URL + `/broadcasting/auth`)
/// rather than Laravel's default session-based `/broadcasting/auth` route,
/// since this app authenticates with a bearer token, not a session cookie.
/// [connect] is idempotent and safe to call from any screen that needs a
/// live channel; the socket is left open across screens (app-lifecycle
/// pause/resume is handled by the package itself) rather than torn down
/// per editor.
class ReverbClient {
  ReverbClient({required SecureTokenStorage tokenStorage})
    : _reverb = Reverb(
        host: AppConfig.reverbHost,
        port: AppConfig.reverbPort,
        appKey: AppConfig.reverbAppKey,
        useTls: AppConfig.reverbUseTLS,
        authEndpoint: '${AppConfig.apiBaseUrl}/broadcasting/auth',
        authHeaders: () async {
          final token = await tokenStorage.readToken();

          return {if (token != null) 'Authorization': 'Bearer $token'};
        },
      );

  final Reverb _reverb;

  Reverb get instance => _reverb;

  Future<void> connect() => _reverb.connect();

  void dispose() => _reverb.dispose();
}
