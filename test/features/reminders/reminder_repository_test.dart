import 'package:flutter_test/flutter_test.dart';
import 'package:memo_life/core/storage/app_database.dart';
import 'package:memo_life/core/storage/sync_query_helpers.dart';
import 'package:memo_life/core/sync/connectivity_service.dart';
import 'package:memo_life/core/sync/sync_manager.dart';
import 'package:memo_life/features/reminders/data/reminder_local_data_source.dart';
import 'package:memo_life/features/reminders/data/reminder_remote_data_source.dart';
import 'package:memo_life/features/reminders/data/reminder_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockReminderRemoteDataSource extends Mock
    implements ReminderRemoteDataSource {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(<String, dynamic>{});
  });

  late Database db;
  late ReminderRepository repository;
  late ReminderLocalDataSource local;
  late _MockReminderRemoteDataSource remote;

  Future<void> insertLocalNote({
    required String localUuid,
    String? serverUuid,
  }) async {
    await db.insert('notes', {
      'local_uuid': localUuid,
      'server_uuid': serverUuid,
      'title': 'Une note',
      'priority': 'normal',
      'color_mode': 'automatic',
      'is_archived': 0,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': serverUuid == null
          ? SyncStatus.pendingCreate
          : SyncStatus.synced,
    });
  }

  Future<void> insertLocalCategory({
    required String localUuid,
    String? serverUuid,
  }) async {
    await db.insert('categories', {
      'local_uuid': localUuid,
      'server_uuid': serverUuid,
      'name': 'Une catégorie',
      'type': 'reminder',
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
    local = ReminderLocalDataSource(AppDatabase.forDatabase(db));
    remote = _MockReminderRemoteDataSource();

    final connectivity = _MockConnectivityService();
    when(() => connectivity.isOnline).thenAnswer((_) async => false);
    when(() => connectivity.onlineChanges)
        .thenAnswer((_) => const Stream.empty());
    final syncManager = SyncManager(connectivity: connectivity);

    repository = ReminderRepository(
      local: local,
      remote: remote,
      syncManager: syncManager,
    );
  });

  group('note FK resolution on push', () {
    test(
      'a reminder linked to an unsynced note is deferred, not pushed',
      () async {
        await insertLocalNote(localUuid: 'note-local-1'); // no server_uuid yet
        await repository.createReminder(
          noteLocalUuid: 'note-local-1',
          title: 'Rappel',
          dueAt: DateTime.now(),
        );

        await repository.pushPending();

        verifyNever(() => remote.create(any()));
        final pending = await local.pendingRows();
        expect(pending, hasLength(1));
      },
    );

    test('once the note has synced, the reminder push resolves note_uuid correctly', () async {
      await insertLocalNote(
        localUuid: 'note-local-1',
        serverUuid: 'note-server-1',
      );
      final reminder = await repository.createReminder(
        noteLocalUuid: 'note-local-1',
        title: 'Rappel',
        dueAt: DateTime.now(),
      );
      when(() => remote.create(any()))
          .thenAnswer((_) async => {'uuid': 'reminder-server-1'});

      await repository.pushPending();

      final captured =
          verify(() => remote.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['note_uuid'], 'note-server-1');
      final stored = await local.getByLocalUuid(reminder.localUuid);
      expect(stored!.serverUuid, 'reminder-server-1');
      expect(stored.syncStatus, SyncStatus.synced);
    });

    test(
      'a reminder with no linked note pushes with a null note_uuid',
      () async {
        await repository.createReminder(
          title: 'Rappel sans note',
          dueAt: DateTime.now(),
        );
        when(() => remote.create(any()))
            .thenAnswer((_) async => {'uuid': 'reminder-server-2'});

        await repository.pushPending();

        final captured =
            verify(() => remote.create(captureAny())).captured.single
                as Map<String, dynamic>;
        expect(captured['note_uuid'], isNull);
      },
    );
  });

  group('category FK resolution on push', () {
    test(
      'a reminder linked to an unsynced category is deferred, not pushed',
      () async {
        await insertLocalCategory(
          localUuid: 'category-local-1',
        ); // no server_uuid yet
        await repository.createReminder(
          categoryLocalUuid: 'category-local-1',
          title: 'Rappel',
          dueAt: DateTime.now(),
        );

        await repository.pushPending();

        verifyNever(() => remote.create(any()));
        final pending = await local.pendingRows();
        expect(pending, hasLength(1));
      },
    );

    test('once the category has synced, the reminder push resolves category_uuid correctly', () async {
      await insertLocalCategory(
        localUuid: 'category-local-1',
        serverUuid: 'category-server-1',
      );
      final reminder = await repository.createReminder(
        categoryLocalUuid: 'category-local-1',
        title: 'Rappel',
        dueAt: DateTime.now(),
      );
      when(() => remote.create(any()))
          .thenAnswer((_) async => {'uuid': 'reminder-server-1'});

      await repository.pushPending();

      final captured =
          verify(() => remote.create(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['category_uuid'], 'category-server-1');
      final stored = await local.getByLocalUuid(reminder.localUuid);
      expect(stored!.serverUuid, 'reminder-server-1');
      expect(stored.syncStatus, SyncStatus.synced);
    });
  });

  group('SyncQueryHelpers.serverUuidFor / localUuidFor', () {
    test('resolves both directions between local and server uuids', () async {
      await insertLocalNote(
        localUuid: 'note-local-9',
        serverUuid: 'note-server-9',
      );

      expect(
        await SyncQueryHelpers.serverUuidFor(db, 'notes', 'note-local-9'),
        'note-server-9',
      );
      expect(
        await SyncQueryHelpers.localUuidFor(db, 'notes', 'note-server-9'),
        'note-local-9',
      );
      expect(
        await SyncQueryHelpers.serverUuidFor(db, 'notes', 'missing'),
        isNull,
      );
      expect(await SyncQueryHelpers.serverUuidFor(db, 'notes', null), isNull);
    });
  });
}
