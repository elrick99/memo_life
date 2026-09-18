/// Implemented by every feature repository that keeps a local sqflite
/// cache in sync with the API. Registered with [SyncManager] in dependency
/// order (parents before children — e.g. accounts before transactions) so
/// that FK resolution (`*_local_uuid` → server `uuid`) always has what it
/// needs by the time a child row is pushed.
abstract class Syncable {
  /// Push every locally pending row (`pending_create` / `pending_update` /
  /// `pending_delete`) to the API. Must not throw on a single row's
  /// failure — record it and continue, so one bad row can't block the rest
  /// of the queue.
  Future<void> pushPending();

  /// Pull the full remote list and reconcile with the local cache:
  /// upsert by `server_uuid` (last-write-wins via `updated_at`), and prune
  /// local rows that are already `synced` but no longer present remotely.
  /// Rows with local pending changes are always kept.
  Future<void> pull();
}
