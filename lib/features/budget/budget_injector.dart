import '../../core/di/service_locator.dart';
import '../../core/sync/sync_manager.dart';
import 'bloc/accounts_bloc.dart';
import 'bloc/categories_bloc.dart';
import 'bloc/saving_goals_bloc.dart';
import 'bloc/transactions_bloc.dart';
import 'data/account_local_data_source.dart';
import 'data/account_remote_data_source.dart';
import 'data/account_repository.dart';
import 'data/category_local_data_source.dart';
import 'data/category_remote_data_source.dart';
import 'data/category_repository.dart';
import 'data/saving_goal_local_data_source.dart';
import 'data/saving_goal_remote_data_source.dart';
import 'data/saving_goal_repository.dart';
import 'data/transaction_local_data_source.dart';
import 'data/transaction_remote_data_source.dart';
import 'data/transaction_repository.dart';

void registerBudgetFeature() {
  getIt
    ..registerLazySingleton<AccountLocalDataSource>(
      () => AccountLocalDataSource(getIt()),
    )
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
      ),
    )
    // Registered as app-lifetime singletons (like AuthBloc), not
    // route-scoped: `go_router`'s `StatefulShellRoute` gives each branch its
    // own nested Navigator, and `Navigator.push` inserts a new route as a
    // *sibling* of the current one in the Overlay — not a descendant — so a
    // BlocProvider scoped to a single branch's route builder is invisible to
    // pages pushed on top of it. Providing these at the app root (see
    // `app.dart`) sidesteps that entirely.
    ..registerLazySingleton<AccountsBloc>(
      () => AccountsBloc(repository: getIt()),
    )
    ..registerLazySingleton<CategoryLocalDataSource>(
      () => CategoryLocalDataSource(getIt()),
    )
    ..registerLazySingleton<CategoryRemoteDataSource>(
      () => CategoryRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
      ),
    )
    ..registerLazySingleton<CategoriesBloc>(
      () => CategoriesBloc(repository: getIt()),
    )
    ..registerLazySingleton<SavingGoalLocalDataSource>(
      () => SavingGoalLocalDataSource(getIt()),
    )
    ..registerLazySingleton<SavingGoalRemoteDataSource>(
      () => SavingGoalRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<SavingGoalRepository>(
      () => SavingGoalRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
      ),
    )
    ..registerLazySingleton<SavingGoalsBloc>(
      () => SavingGoalsBloc(repository: getIt()),
    )
    ..registerLazySingleton<TransactionLocalDataSource>(
      () => TransactionLocalDataSource(getIt()),
    )
    ..registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepository(
        local: getIt(),
        remote: getIt(),
        syncManager: getIt(),
        accountRepository: getIt(),
      ),
    )
    ..registerLazySingleton<TransactionsBloc>(
      () => TransactionsBloc(repository: getIt()),
    );

  // Dependency order matters: accounts and categories must sync before the
  // transactions that reference them (see TransactionRepository doc-comment).
  // Saving goals have no FK dependents, so their position is unconstrained.
  getIt<SyncManager>()
    ..register(getIt<AccountRepository>())
    ..register(getIt<CategoryRepository>())
    ..register(getIt<SavingGoalRepository>())
    ..register(getIt<TransactionRepository>());
}
