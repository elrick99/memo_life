import '../../core/di/service_locator.dart';
import '../../core/sync/sync_manager.dart';
import 'bloc/notes_bloc.dart';
import 'data/note_collaborator_remote_data_source.dart';
import 'data/note_local_data_source.dart';
import 'data/note_lock_service.dart';
import 'data/note_public_remote_data_source.dart';
import 'data/note_realtime_remote_data_source.dart';
import 'data/note_remote_data_source.dart';
import 'data/note_repository.dart';
import 'data/note_share_link_remote_data_source.dart';
import 'data/tag_local_data_source.dart';
import 'data/tag_remote_data_source.dart';
import 'data/tag_repository.dart';

void registerNotesFeature() {
  getIt
    ..registerLazySingleton<TagLocalDataSource>(
      () => TagLocalDataSource(getIt()),
    )
    ..registerLazySingleton<TagRemoteDataSource>(
      () => TagRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<TagRepository>(
      () =>
          TagRepository(local: getIt(), remote: getIt(), syncManager: getIt()),
    )
    ..registerLazySingleton<NoteLocalDataSource>(
      () => NoteLocalDataSource(getIt()),
    )
    ..registerLazySingleton<NoteRemoteDataSource>(
      () => NoteRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<NoteShareLinkRemoteDataSource>(
      () => NoteShareLinkRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<NoteCollaboratorRemoteDataSource>(
      () => NoteCollaboratorRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<NoteRealtimeRemoteDataSource>(
      () => NoteRealtimeRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<NotePublicRemoteDataSource>(
      () => NotePublicRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<NoteLockService>(NoteLockService.new)
    ..registerLazySingleton<NoteRepository>(
      () => NoteRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
        tags: getIt(),
        attachmentRepository: getIt(),
      ),
    )
    // App-lifetime singleton, provided at the app root in `app.dart` — see
    // the matching comment in `budget_injector.dart` for why (Navigator.push
    // makes a route-scoped provider invisible to routes pushed on top of it).
    ..registerLazySingleton<NotesBloc>(() => NotesBloc(repository: getIt()));

  // Tags must sync before notes: a note's tag_local_uuids resolve to the
  // tags' server_uuids at push time (see NoteRepository). Notes have no
  // cross-feature FK dependents of their own (reminders point at them, so
  // notes must sync before reminders — registered first here).
  getIt<SyncManager>()
    ..register(getIt<TagRepository>())
    ..register(getIt<NoteRepository>());
}
