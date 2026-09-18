/// Mirrors `NoteCollaboratorResource` — collaborator metadata is
/// server-authoritative and fetched fresh, never cached/synced offline like
/// [NoteModel] itself.
class NoteCollaboratorModel {
  const NoteCollaboratorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.invitedEmail,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;

  /// The email this person was invited with, frozen at invite time — can
  /// differ from [email] (the account's current email) if they changed it
  /// since accepting.
  final String? invitedEmail;

  bool get isOwner => role == 'owner';

  factory NoteCollaboratorModel.fromJson(Map<String, dynamic> json) =>
      NoteCollaboratorModel(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
        invitedEmail: json['invited_email'] as String?,
      );
}
