import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_manager.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._repository, required this._syncManager})
    : super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthGuestModeEntered>(_onGuestModeEntered);
    on<AuthUserRefreshed>(_onUserRefreshed);
  }

  final AuthRepository _repository;
  final SyncManager _syncManager;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _repository.restoreSession();
    if (user != null) {
      _syncManager.isGuest = false;
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isGuest: false,
        ),
      );

      return;
    }
    if (await _repository.isGuest()) {
      _syncManager.isGuest = true;
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          clearUser: true,
          isGuest: true,
        ),
      );

      return;
    }
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final wasGuest = state.isGuest;
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      final user = await _repository.login(
        email: event.email,
        password: event.password,
      );
      await _onAccountLinked(wasGuest: wasGuest);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isGuest: false,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> _onRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final wasGuest = state.isGuest;
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      final user = await _repository.register(
        name: event.name,
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
      );
      await _onAccountLinked(wasGuest: wasGuest);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isGuest: false,
        ),
      );
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: error.message,
        ),
      );
    }
  }

  /// A guest who just registered/logged in now has a token — stop treating
  /// the session as local-only and push everything they created offline.
  Future<void> _onAccountLinked({required bool wasGuest}) async {
    if (!wasGuest) {
      return;
    }
    await _repository.exitGuestMode();
    _syncManager.isGuest = false;
    unawaited(_syncManager.runSync());
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    _syncManager.isGuest = false;
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onGuestModeEntered(
    AuthGuestModeEntered event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.enterGuestMode();
    _syncManager.isGuest = true;
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        clearUser: true,
        isGuest: true,
        clearError: true,
      ),
    );
  }

  Future<void> _onUserRefreshed(
    AuthUserRefreshed event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.updateCachedUser(event.user);
    emit(state.copyWith(user: event.user));
  }
}
