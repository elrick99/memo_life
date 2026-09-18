import 'package:flutter_test/flutter_test.dart';
import 'package:memo_life/core/sync/connectivity_service.dart';
import 'package:memo_life/core/sync/sync_manager.dart';
import 'package:memo_life/features/auth/bloc/auth_bloc.dart';
import 'package:memo_life/features/auth/data/auth_repository.dart';
import 'package:memo_life/features/auth/data/auth_user.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late _MockAuthRepository repository;
  late SyncManager syncManager;
  late AuthBloc bloc;

  setUp(() {
    repository = _MockAuthRepository();
    final connectivity = _MockConnectivityService();
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => connectivity.onlineChanges)
        .thenAnswer((_) => const Stream.empty());
    syncManager = SyncManager(connectivity: connectivity);
    bloc = AuthBloc(repository: repository, syncManager: syncManager);
  });

  tearDown(() async {
    await bloc.close();
    syncManager.dispose();
  });

  test(
    'entering guest mode marks the sync manager as guest and never syncs',
    () async {
      when(() => repository.enterGuestMode()).thenAnswer((_) async {});

      bloc.add(const AuthGuestModeEntered());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == AuthStatus.authenticated,
      );

      expect(state.isGuest, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(syncManager.isGuest, isTrue);
      verify(() => repository.enterGuestMode()).called(1);
    },
  );

  test(
    'logging in while a guest exits guest mode and triggers a sync pass',
    () async {
      when(() => repository.enterGuestMode()).thenAnswer((_) async {});
      when(() => repository.exitGuestMode()).thenAnswer((_) async {});
      const user = AuthUser(
        id: 1,
        name: 'Awa',
        email: 'awa@memo-life.test',
        isActive: true,
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);

      bloc.add(const AuthGuestModeEntered());
      await bloc.stream.firstWhere((s) => s.isGuest);
      expect(syncManager.isGuest, isTrue);

      bloc.add(
        const AuthLoginSubmitted(
          email: 'awa@memo-life.test',
          password: 'secret',
        ),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s.status == AuthStatus.authenticated && !s.isGuest,
      );

      expect(state.user, user);
      expect(syncManager.isGuest, isFalse);
      verify(() => repository.exitGuestMode()).called(1);
      // The account-linked sync pass should have run at least once — with no
      // repositories registered it's a trivial success, but the phase must
      // move off `localOnly` to prove `runSync` actually executed.
      await Future<void>.delayed(Duration.zero);
      expect(syncManager.state.phase, isNot(SyncPhase.localOnly));
    },
  );

  test(
    'logging in normally (never guest) never touches the guest flag',
    () async {
      const user = AuthUser(
        id: 2,
        name: 'Kofi',
        email: 'kofi@memo-life.test',
        isActive: true,
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);

      bloc.add(
        const AuthLoginSubmitted(
          email: 'kofi@memo-life.test',
          password: 'secret',
        ),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s.status == AuthStatus.authenticated,
      );

      expect(state.user, user);
      expect(state.isGuest, isFalse);
      verifyNever(() => repository.exitGuestMode());
    },
  );
}
