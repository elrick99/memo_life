/// Mirrors the raw `User` model serialization returned by
/// `AuthController` (`/auth/register`, `/auth/login`, `/auth/me`) —
/// every column except the `#[Hidden]`-attributed secrets.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isActive,
    this.isAdmin = false,
    this.currentTeamId,
    this.hasTwoFactorEnabled = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    isActive: json['is_active'] as bool? ?? true,
    isAdmin: json['is_admin'] as bool? ?? false,
    currentTeamId: json['current_team_id'] as int?,
    hasTwoFactorEnabled: json['two_factor_confirmed_at'] != null,
  );

  final int id;
  final String name;
  final String email;
  final bool isActive;
  final bool isAdmin;
  final int? currentTeamId;
  final bool hasTwoFactorEnabled;

  AuthUser copyWith({bool? hasTwoFactorEnabled}) => AuthUser(
    id: id,
    name: name,
    email: email,
    isActive: isActive,
    isAdmin: isAdmin,
    currentTeamId: currentTeamId,
    hasTwoFactorEnabled: hasTwoFactorEnabled ?? this.hasTwoFactorEnabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'is_active': isActive,
    'is_admin': isAdmin,
    'current_team_id': currentTeamId,
    'two_factor_confirmed_at': hasTwoFactorEnabled
        ? DateTime.now().toIso8601String()
        : null,
  };
}
