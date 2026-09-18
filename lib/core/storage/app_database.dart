import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Sync-status values shared by every offline-first table. See the
/// `sync` package doc-comment on [SyncStatus] for the full lifecycle.
class SyncStatus {
  const SyncStatus._();

  static const synced = 'synced';
  static const pendingCreate = 'pending_create';
  static const pendingUpdate = 'pending_update';
  static const pendingDelete = 'pending_delete';
}

/// Opens and migrates the offline sqflite database. Every syncable table
/// shares the same identity shape:
///  - `local_uuid` (PK) — client-generated, stable, never changes.
///  - `server_uuid` — null until the row is first pushed; becomes the API
///    route key (`/notes/{uuid}`, ...) from then on.
///  - `updated_at` — local last-modified timestamp, used for last-write-wins
///    conflict resolution on pull.
///  - `sync_status` — one of [SyncStatus].
///
/// Cross-references between tables (e.g. a transaction's account, a
/// reminder's note) point at `*_local_uuid`, because a locally-created
/// parent may not have a `server_uuid` yet — the sync manager resolves
/// these to the parent's `server_uuid` only when pushing.
class AppDatabase {
  AppDatabase._();

  /// Wraps an already-open [Database] (e.g. an in-memory one built with
  /// `sqflite_common_ffi` + [createSchema] in tests) instead of opening the
  /// real on-disk singleton.
  AppDatabase.forDatabase(Database db) : _db = db;

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'memo_life.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) => createSchema(db),
    );
  }

  /// Exposed (not just `_onCreate`) so repository/sync unit tests can build
  /// the same schema against an isolated in-memory database instead of
  /// going through the singleton.
  static Future<void> createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE accounts (
        local_uuid   TEXT PRIMARY KEY,
        server_uuid  TEXT UNIQUE,
        name         TEXT NOT NULL,
        type         TEXT NOT NULL,
        balance      REAL NOT NULL DEFAULT 0,
        currency     TEXT NOT NULL DEFAULT 'XOF',
        icon         TEXT,
        color        TEXT,
        created_at   TEXT,
        updated_at   TEXT NOT NULL,
        sync_status  TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE categories (
        local_uuid   TEXT PRIMARY KEY,
        server_uuid  TEXT UNIQUE,
        name         TEXT NOT NULL,
        type         TEXT NOT NULL,
        is_system    INTEGER NOT NULL DEFAULT 0,
        color        TEXT,
        icon         TEXT,
        updated_at   TEXT NOT NULL,
        sync_status  TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE saving_goals (
        local_uuid     TEXT PRIMARY KEY,
        server_uuid    TEXT UNIQUE,
        name           TEXT NOT NULL,
        target_amount  REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        target_date    TEXT,
        color          TEXT,
        updated_at     TEXT NOT NULL,
        sync_status    TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE tags (
        local_uuid   TEXT PRIMARY KEY,
        server_uuid  TEXT UNIQUE,
        name         TEXT NOT NULL,
        color        TEXT,
        updated_at   TEXT NOT NULL,
        sync_status  TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE notes (
        local_uuid           TEXT PRIMARY KEY,
        server_uuid          TEXT UNIQUE,
        category_local_uuid  TEXT REFERENCES categories (local_uuid) ON DELETE SET NULL,
        tag_local_uuids       TEXT,
        title                TEXT NOT NULL,
        content              TEXT,
        content_format       TEXT NOT NULL DEFAULT 'plain',
        checklist            TEXT,
        priority             TEXT NOT NULL DEFAULT 'normal',
        color                TEXT,
        color_mode           TEXT NOT NULL DEFAULT 'automatic',
        is_archived          INTEGER NOT NULL DEFAULT 0,
        is_pinned            INTEGER NOT NULL DEFAULT 0,
        is_locked            INTEGER NOT NULL DEFAULT 0,
        created_at           TEXT,
        updated_at           TEXT NOT NULL,
        sync_status          TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE reminders (
        local_uuid           TEXT PRIMARY KEY,
        server_uuid          TEXT UNIQUE,
        note_local_uuid      TEXT REFERENCES notes (local_uuid) ON DELETE SET NULL,
        category_local_uuid  TEXT REFERENCES categories (local_uuid) ON DELETE SET NULL,
        title                TEXT NOT NULL,
        description          TEXT,
        due_at               TEXT NOT NULL,
        location             TEXT,
        type                 TEXT NOT NULL,
        priority             TEXT NOT NULL,
        recurrence           TEXT NOT NULL DEFAULT 'none',
        is_completed         INTEGER NOT NULL DEFAULT 0,
        is_pinned            INTEGER NOT NULL DEFAULT 0,
        updated_at           TEXT NOT NULL,
        sync_status          TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE transactions (
        local_uuid                       TEXT PRIMARY KEY,
        server_uuid                      TEXT UNIQUE,
        account_local_uuid               TEXT NOT NULL REFERENCES accounts (local_uuid) ON DELETE CASCADE,
        destination_account_local_uuid   TEXT REFERENCES accounts (local_uuid) ON DELETE SET NULL,
        category_local_uuid              TEXT REFERENCES categories (local_uuid) ON DELETE SET NULL,
        type                             TEXT NOT NULL,
        amount                           REAL NOT NULL,
        occurred_at                      TEXT NOT NULL,
        description                      TEXT,
        attachment_path                  TEXT,
        updated_at                       TEXT NOT NULL,
        sync_status                      TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute('''
      CREATE TABLE attachments (
        local_uuid              TEXT PRIMARY KEY,
        server_uuid              TEXT UNIQUE,
        attachable_type          TEXT NOT NULL,
        attachable_local_uuid    TEXT NOT NULL,
        local_file_path          TEXT,
        filename                 TEXT NOT NULL,
        mime_type                TEXT,
        size                     INTEGER NOT NULL DEFAULT 0,
        updated_at               TEXT NOT NULL,
        sync_status              TEXT NOT NULL DEFAULT '${SyncStatus.pendingCreate}'
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_notes_category ON notes (category_local_uuid)',
    );
    batch.execute(
      'CREATE INDEX idx_reminders_note ON reminders (note_local_uuid)',
    );
    batch.execute(
      'CREATE INDEX idx_reminders_category ON reminders (category_local_uuid)',
    );
    batch.execute(
      'CREATE INDEX idx_attachments_owner ON attachments (attachable_type, attachable_local_uuid)',
    );
    batch.execute(
      'CREATE INDEX idx_transactions_account ON transactions (account_local_uuid)',
    );
    batch.execute(
      'CREATE INDEX idx_transactions_occurred_at ON transactions (occurred_at)',
    );

    batch.execute('''
      CREATE TABLE app_meta (
        key    TEXT PRIMARY KEY,
        value  TEXT
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// For sign-out: wipes every cached row without dropping the schema.
  Future<void> clearAll() async {
    final db = await database;
    final batch = db.batch();
    for (final table in const [
      'attachments',
      'transactions',
      'reminders',
      'notes',
      'saving_goals',
      'categories',
      'tags',
      'accounts',
      'app_meta',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }
}
