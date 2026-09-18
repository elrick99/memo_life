part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.isGuest = false,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  /// True once the user picked "Continuer sans compte" — no token, no
  /// sync, everything stays local until they register/log in for real.
  final bool isGuest;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && (user != null || isGuest);

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
    bool? isGuest,
  }) => AuthState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    isGuest: isGuest ?? this.isGuest,
  );

  @override
  List<Object?> get props => [status, user, errorMessage, isGuest];
}
