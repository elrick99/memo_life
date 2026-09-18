import 'package:flutter_test/flutter_test.dart';
import 'package:memo_life/core/storage/app_database.dart';
import 'package:memo_life/core/sync/connectivity_service.dart';
import 'package:memo_life/core/sync/sync_manager.dart';
import 'package:memo_life/features/notes/data/note_local_data_source.dart';
import 'package:memo_life/features/notes/data/note_model.dart';
import 'package:memo_life/features/notes/data/note_remote_data_source.dart';
import 'package:memo_life/features/notes/data/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockNoteRemoteDataSource extends Mock implements NoteRemoteDataSource {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late NoteRepository repository;
  late NoteLocalDataSource local;
  late _MockNoteRemoteDataSource remote;

  Future<void> insertLocalCategory({
    required String localUuid,
    String? serverUuid,
  }) async {
    await db.insert('categories', {
      'local_uuid': localUuid,
      'server_uuid': serverUuid,
      'name': 'Une catégorie',
      'type': 'note',
      'is_system': 0,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': serverUuid == null
          ? SyncStatus.pendingCreate
          : SyncStatus.synced,
    });
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await AppDatabase.createSchema(db);
    local = NoteLocalDataSource(AppDatabase.forDatabase(db));
    remote = _MockNoteRemoteDataSource();

    final connectivity = _MockConnectivityService();
    when(() => connectivity.isOnline).thenAnswer((_) async => false);
    when(() => connectivity.onlineChanges)
        .thenAnswer((_) => const Stream.empty());
    final syncManager = SyncManager(connectivity: connectivity);

    repository = NoteRepository(
      local: local,
      remote: remote,
      syncManager: syncManager,
    );
  });

  group('pushPending', () {
    test(
      'a locally-created note is pushed once and gets a server_uuid',
      () async {
        final note = await repository.createNote(title: 'Courses');
        when(() => remote.create(any())).thenAnswer(
          (_) async => {
            'uuid': 'server-1',
            'title': 'Courses',
            'priority': 'normal',
            'color_mode': 'automatic',
            'is_archived': false,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );

        await repository.pushPending();

        final stored = await local.getByLocalUuid(note.localUuid);
        expect(stored!.serverUuid, 'server-1');
        expect(stored.syncStatus, SyncStatus.synced);
        verify(() => remote.create(any())).called(1);
      },
    );

    test(
      'a failed push leaves the row pending for retry on the next sync',
      () async {
        await repository.createNote(title: 'Idées cadeaux');
        when(() => remote.create(any())).thenThrow(Exception('network blip'));

        // pushPending swallows ApiException per-row; a raw Exception here
        // would surface, which is fine — this asserts it doesn't corrupt the
        // local row either way.
        await expectLater(repository.pushPending(), throwsException);

        final rows = await local.pendingRows();
        expect(rows, hasLength(1));
        expect(rows.first['sync_status'], SyncStatus.pendingCreate);
      },
    );
  });

  group('category FK resolution on push', () {
    test(
      'a note linked to an unsynced category is deferred, not pushed',
      () async {
        await insertLocalCategory(
          localUuid: 'category-local-1',
        ); // no server_uuid yet
        await repository.createNote(
          categoryLocalUuid: 'category-local-1',
          title: 'Idée',
        );

        await repository.pushPending();

        verifyNever(() => remote.create(any()));
        final pending = await local.pendingRows();
        expect(pending, hasLength(1));
      },
    );

    test('once the category has synced, the note push resolves category_uuid correctly', () async {
      await insertLocalCategory(
        localUuid: 'category-local-1',
        serverUuid: 'category-server-1',
      );
      final note = await repository.createNote(
        categoryLocalUuid: 'category-local-1',
        title: 'Idée',
      );
      when(() => remote.create(any())).thenAnswer(
        (_) async => {
          'uuid': 'server-1',
          'title': 'Idée',
          'priority': 'normal',
          'color_mode': 'automatic',
          'is_archived': false,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      await repository.pushPending();

      final captured =
          verify(() => remote.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['category_uuid'], 'category-server-1');
      final stored = await local.getByLocalUuid(note.localUuid);
      expect(stored!.serverUuid, 'server-1');
      expect(stored.syncStatus, SyncStatus.synced);
    });
  });

  group('pull — last-write-wins reconciliation', () {
    test(
      'a newer server record overwrites an older synced local row',
      () async {
        final old = DateTime(2026, 1, 1);
        final newer = DateTime(2026, 1, 2);
        await local.upsert(
          NoteModel(
            localUuid: 'local-1',
            serverUuid: 'server-1',
            title: 'Old title',
            updatedAt: old,
            syncStatus: SyncStatus.synced,
          ),
        );
        when(() => remote.index(page: 1)).thenAnswer(
          (_) async => NotePage(
            items: [
              {
                'uuid': 'server-1',
                'title': 'New title',
                'priority': 'normal',
                'color_mode': 'automatic',
                'is_archived': false,
                'updated_at': newer.toIso8601String(),
              },
            ],
            lastPage: 1,
          ),
        );

        await repository.pull();

        final stored = await local.getByLocalUuid('local-1');
        expect(stored!.title, 'New title');
      },
    );

    test(
      'a stale server record does not overwrite a newer local row',
      () async {
        final newer = DateTime(2026, 1, 5);
        final older = DateTime(2026, 1, 1);
        await local.upsert(
          NoteModel(
            localUuid: 'local-1',
            serverUuid: 'server-1',
            title: 'Locally edited title',
            updatedAt: newer,
            syncStatus: SyncStatus.synced,
          ),
        );
        when(() => remote.index(page: 1)).thenAnswer(
          (_) async => NotePage(
            items: [
              {
                'uuid': 'server-1',
                'title': 'Stale server title',
                'priority': 'normal',
                'color_mode': 'automatic',
                'is_archived': false,
                'updated_at': older.toIso8601String(),
              },
            ],
            lastPage: 1,
          ),
        );

        await repository.pull();

        final stored = await local.getByLocalUuid('local-1');
        expect(stored!.title, 'Locally edited title');
      },
    );

    test(
      'a row with unsynced local changes is never overwritten by a pull',
      () async {
        await local.upsert(
          NoteModel(
            localUuid: 'local-1',
            serverUuid: 'server-1',
            title: 'Pending edit',
            updatedAt: DateTime(2026, 1, 10),
            syncStatus: SyncStatus.pendingUpdate,
          ),
        );
        when(() => remote.index(page: 1)).thenAnswer(
          (_) async => NotePage(
            items: [
              {
                'uuid': 'server-1',
                'title': 'Server version',
                'priority': 'normal',
                'color_mode': 'automatic',
                'is_archived': false,
                // Even a much newer server timestamp must not win here —
                // the local pending edit hasn't been pushed yet.
                'updated_at': DateTime(2026, 6, 1).toIso8601String(),
              },
            ],
            lastPage: 1,
          ),
        );

        await repository.pull();

        final stored = await local.getByLocalUuid('local-1');
        expect(stored!.title, 'Pending edit');
        expect(stored.syncStatus, SyncStatus.pendingUpdate);
      },
    );

    test('a synced local row absent from the pull is pruned', () async {
      await local.upsert(
        NoteModel(
          localUuid: 'local-1',
          serverUuid: 'server-deleted',
          title: 'Deleted on another device',
          updatedAt: DateTime(2026, 1, 1),
          syncStatus: SyncStatus.synced,
        ),
      );
      when(() => remote.index(page: 1))
          .thenAnswer((_) async => const NotePage(items: [], lastPage: 1));

      await repository.pull();

      expect(await local.getByLocalUuid('local-1'), isNull);
    });
  });
}
