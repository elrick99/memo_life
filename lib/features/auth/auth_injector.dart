import '../../core/di/service_locator.dart';
import 'bloc/auth_bloc.dart';
import 'data/auth_remote_data_source.dart';
import 'data/auth_repository.dart';

void registerAuthFeature() {
  getIt
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(
        remote: getIt(),
        tokenStorage: getIt(),
        connectivity: getIt(),
        database: getIt(),
      ),
    )
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(repository: getIt(), syncManager: getIt()),
    );
}
