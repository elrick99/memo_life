part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at app boot to resolve the initial session state.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterSubmitted extends AuthEvent {
  const AuthRegisterSubmitted({
    required this.name,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
  });

  final String name;
  final String email;
  final String password;
  final String passwordConfirmation;

  @override
  List<Object?> get props => [name, email, password, passwordConfirmation];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

/// Dispatched from the login screen's "Continuer sans compte" button.
class AuthGuestModeEntered extends AuthEvent {
  const AuthGuestModeEntered();
}

/// Dispatched by the Profile screen after a successful name/email update,
/// so the app-wide session state (and its offline cache) stays in sync.
class AuthUserRefreshed extends AuthEvent {
  const AuthUserRefreshed(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}
