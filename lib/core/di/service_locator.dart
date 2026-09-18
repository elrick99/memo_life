import 'package:get_it/get_it.dart';

import '../../features/attachments/attachments_injector.dart';
import '../../features/auth/auth_injector.dart';
import '../../features/budget/budget_injector.dart';
import '../../features/notes/notes_injector.dart';
import '../../features/reminders/reminders_injector.dart';
import '../../features/security/security_injector.dart';
import '../network/api_client.dart';
import '../realtime/reverb_client.dart';
import '../storage/app_database.dart';
import '../storage/secure_token_storage.dart';
import '../sync/connectivity_service.dart';
import '../sync/sync_manager.dart';

final getIt = GetIt.instance;

/// Registers core singletons, then each feature's own repositories/blocs.
/// Call once, before `runApp`.
Future<void> setupServiceLocator() async {
  getIt
    ..registerLazySingleton<SecureTokenStorage>(SecureTokenStorage.new)
    ..registerLazySingleton<ApiClient>(() => ApiClient(tokenStorage: getIt()))
    ..registerLazySingleton<ReverbClient>(
      () => ReverbClient(tokenStorage: getIt()),
    )
    ..registerLazySingleton<AppDatabase>(() => AppDatabase.instance)
    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)
    ..registerLazySingleton<SyncManager>(
      () => SyncManager(connectivity: getIt()),
    );

  registerAuthFeature();
  registerSecurityFeature();
  // Budget (which registers CategoryRepository) must come before Notes and
  // Reminders: both now carry an optional category FK that has to resolve
  // to the category's `server_uuid` at push time, so categories need to
  // have synced first — see SyncManager.register's doc-comment.
  registerBudgetFeature();
  // DI-only: Notes/Reminders repositories need an AttachmentRepository
  // instance injected — see registerAttachmentsFeature's doc-comment for
  // why this can't simply move after them.
  registerAttachmentsFeature();
  registerNotesFeature();
  registerRemindersFeature();
  // Sync order: attachments push last, since resolving their parent FK
  // needs the parent note/reminder to already have a server_uuid.
  registerAttachmentsSync();
}
