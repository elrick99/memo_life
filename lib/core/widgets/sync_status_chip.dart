import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../sync/sync_manager.dart';

/// Small tappable status indicator (app bar action) showing the current
/// sync phase; tapping it triggers a manual [SyncManager.runSync].
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final syncManager = GetIt.instance<SyncManager>();

    return StreamBuilder<SyncState>(
      stream: syncManager.stateStream,
      initialData: syncManager.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const SyncState(SyncPhase.idle);

        return IconButton(
          tooltip: _tooltip(state),
          onPressed: () => syncManager.runSync(),
          icon: _icon(context, state.phase),
        );
      },
    );
  }

  Widget _icon(BuildContext context, SyncPhase phase) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return switch (phase) {
      SyncPhase.syncing => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      SyncPhase.offline => Icon(Icons.cloud_off_rounded, color: color),
      SyncPhase.error => Icon(
        Icons.sync_problem_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
      SyncPhase.localOnly => Icon(Icons.smartphone_rounded, color: color),
      SyncPhase.success ||
      SyncPhase.idle => Icon(Icons.cloud_done_rounded, color: color),
    };
  }

  String _tooltip(SyncState state) {
    return switch (state.phase) {
      SyncPhase.syncing => 'Synchronisation en cours…',
      SyncPhase.offline => 'Hors ligne — en attente de connexion',
      SyncPhase.error => 'Échec de synchronisation — appuyer pour réessayer',
      SyncPhase.localOnly => 'Mode local — aucune synchronisation',
      SyncPhase.success =>
        state.lastSyncedAt != null
            ? 'Synchronisé à ${DateFormat.Hm('fr_FR').format(state.lastSyncedAt!)}'
            : 'Synchronisé',
      SyncPhase.idle => 'Appuyer pour synchroniser',
    };
  }
}

/// Convenience mixin-free helper: wrap a widget subtree to rebuild whenever
/// sync state changes without pulling in a full Bloc for it.
class SyncStateListener extends StatelessWidget {
  const SyncStateListener({super.key, required this.builder});

  final Widget Function(BuildContext context, SyncState state) builder;

  @override
  Widget build(BuildContext context) {
    final syncManager = GetIt.instance<SyncManager>();

    return StreamBuilder<SyncState>(
      stream: syncManager.stateStream,
      initialData: syncManager.state,
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? const SyncState(SyncPhase.idle)),
    );
  }
}
