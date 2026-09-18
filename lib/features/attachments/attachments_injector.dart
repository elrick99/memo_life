import '../../core/di/service_locator.dart';
import '../../core/sync/sync_manager.dart';
import 'data/attachment_local_data_source.dart';
import 'data/attachment_remote_data_source.dart';
import 'data/attachment_repository.dart';

/// DI registration only — deliberately separate from [registerAttachmentsSync].
/// `NoteRepository`/`ReminderRepository`'s own constructors need an
/// `AttachmentRepository` instance, and each resolves its own repository
/// (eagerly, via `getIt<SyncManager>().register(getIt<...Repository>())`)
/// before this feature's sync registration runs — so the DI registration
/// must happen first, even though sync must run last. See
/// `service_locator.dart` for the required call order.
void registerAttachmentsFeature() {
  getIt
    ..registerLazySingleton<AttachmentLocalDataSource>(
      () => AttachmentLocalDataSource(getIt()),
    )
    ..registerLazySingleton<AttachmentRemoteDataSource>(
      () => AttachmentRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<AttachmentRepository>(
      () => AttachmentRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
      ),
    );
}

/// Must run after `registerNotesFeature`/`registerRemindersFeature`: pushing
/// a pending attachment resolves its parent note/reminder's `server_uuid`,
/// which only exists once those have synced (see [AttachmentRepository]'s
/// class doc-comment).
void registerAttachmentsSync() {
  getIt<SyncManager>().register(getIt<AttachmentRepository>());
}
