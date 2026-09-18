import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts any [Stream] (here, a Bloc's state stream) into a [Listenable]
/// so `go_router`'s `refreshListenable` re-evaluates `redirect` whenever
/// auth status changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
