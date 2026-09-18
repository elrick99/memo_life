import '../../core/di/service_locator.dart';
import 'data/security_remote_data_source.dart';
import 'data/security_repository.dart';

void registerSecurityFeature() {
  getIt
    ..registerLazySingleton<SecurityRemoteDataSource>(
      () => SecurityRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<SecurityRepository>(
      () => SecurityRepository(getIt()),
    );
}
