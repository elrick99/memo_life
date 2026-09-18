import 'dart:async';

import 'connectivity_service.dart';
import 'syncable.dart';

enum SyncPhase { idle, syncing, success, error, offline, localOnly }

class SyncState {
  const SyncState(this.phase, {this.lastSyncedAt, this.message});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    String? message,
  }) => SyncState(
    phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
  );
}

/// Orchestrates "semi-automatic" sync: nothing polls, but a sync is
/// attempted whenever connectivity flips online (debounced, so a flaky
/// connection doesn't fire a burst of attempts), and can also be triggered
/// manually (pull-to-refresh, right after a local mutation).
///
/// Repositories register themselves in dependency order — see [register] —
/// and [runSync] always pushes every registered repository's pending
/// changes first, then pulls, so parents (accounts, categories, notes)
/// have a `server_uuid` before children (transactions, reminders) that
/// reference them are pushed.
class SyncManager {
  SyncManager({required this._connectivity}) {
    _connectivitySubscription = _connectivity.onlineChanges.listen((online) {
      if (isGuest) {
        return;
      }
      if (online) {
        _scheduleDebouncedSync();
      } else {
        _emit(_state.copyWith(phase: SyncPhase.offline));
      }
    });
  }

  final ConnectivityService _connectivity;
  final List<Syncable> _syncables = [];
  final _controller = StreamController<SyncState>.broadcast();
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _debounce;
  bool _isSyncing = false;
  SyncState _state = const SyncState(SyncPhase.idle);

  /// Set by [AuthBloc] while the app has no account (guest mode): every
  /// mutation still writes local-first as usual, but [runSync] becomes a
  /// no-op so a guest never sees a spurious 401 sync error.
  bool isGuest = false;

  Stream<SyncState> get stateStream => _controller.stream;

  SyncState get state => _state;

  /// Order matters: register parents before the children that reference
  /// them (accounts, categories, saving_goals, notes, then reminders,
  /// then transactions).
  void register(Syncable syncable) => _syncables.add(syncable);

  void _scheduleDebouncedSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), runSync);
  }

  /// Safe to call freely (pull-to-refresh, post-mutation, app resume) —
  /// no-ops while offline or while a sync is already running.
  Future<void> runSync() async {
    if (isGuest) {
      _emit(_state.copyWith(phase: SyncPhase.localOnly));

      return;
    }
    if (_isSyncing) {
      return;
    }
    if (!await _connectivity.isOnline) {
      _emit(_state.copyWith(phase: SyncPhase.offline));

      return;
    }

    _isSyncing = true;
    _emit(_state.copyWith(phase: SyncPhase.syncing));

    // Each repository's push/pull is isolated: one module failing (a bad
    // API response, a parsing bug, ...) must not stop the ones registered
    // after it in dependency order from getting their own chance to sync.
    String? firstError;
    for (final syncable in _syncables) {
      try {
        await syncable.pushPending();
      } catch (error) {
        firstError ??= error.toString();
      }
    }
    for (final syncable in _syncables) {
      try {
        await syncable.pull();
      } catch (error) {
        firstError ??= error.toString();
      }
    }

    _emit(
      firstError == null
          ? SyncState(SyncPhase.success, lastSyncedAt: DateTime.now())
          : _state.copyWith(phase: SyncPhase.error, message: firstError),
    );
    _isSyncing = false;
  }

  void _emit(SyncState next) {
    _state = next;
    _controller.add(next);
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_controller.close());
  }
}
