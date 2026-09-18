import '../../core/di/service_locator.dart';
import '../../core/sync/sync_manager.dart';
import 'bloc/reminders_bloc.dart';
import 'data/reminder_collaborator_remote_data_source.dart';
import 'data/reminder_local_data_source.dart';
import 'data/reminder_remote_data_source.dart';
import 'data/reminder_repository.dart';

void registerRemindersFeature() {
  getIt
    ..registerLazySingleton<ReminderLocalDataSource>(
      () => ReminderLocalDataSource(getIt()),
    )
    ..registerLazySingleton<ReminderRemoteDataSource>(
      () => ReminderRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<ReminderCollaboratorRemoteDataSource>(
      () => ReminderCollaboratorRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<ReminderRepository>(
      () => ReminderRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
        attachmentRepository: getIt(),
      ),
    )
    // App-lifetime singleton, provided at the app root — see the matching
    // comment in `budget_injector.dart`.
    ..registerLazySingleton<RemindersBloc>(
      () => RemindersBloc(repository: getIt()),
    );

  // Registered after notes: a reminder's note FK can only resolve once the
  // note it points at has synced (see ReminderRepository doc-comment).
  getIt<SyncManager>().register(getIt<ReminderRepository>());
}
