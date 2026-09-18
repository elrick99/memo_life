import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around `connectivity_plus`: tells us a network interface is
/// up (wifi/mobile), which is the standard, low-cost signal for "try a
/// sync now" — not a guarantee of actual internet reachability, but good
/// enough here since a sync attempt that fails just falls back silently.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isOnline(results));
    });
  }

  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final _controller = StreamController<bool>.broadcast();

  /// Emits whenever connectivity flips between online/offline.
  Stream<bool> get onlineChanges => _controller.stream;

  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}
