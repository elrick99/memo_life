import '../../../core/network/api_client.dart';
import 'note_collaborator_model.dart';

/// Result of inviting a collaborator — mirrors the ad-hoc payload
/// `NoteCollaboratorController::store` returns (not a `NoteCollaboratorResource`,
/// since it also carries the one-time `invitation_url`/`delivery` fields).
class NoteInvitationResult {
  const NoteInvitationResult({
    required this.email,
    required this.role,
    required this.delivery,
  });

  factory NoteInvitationResult.fromJson(Map<String, dynamic> json) =>
      NoteInvitationResult(
        email: json['email'] as String,
        role: json['role'] as String,
        delivery: json['delivery'] as String,
      );

  final String email;
  final String role;

  /// `'in_app'` if the invitee already has an account, `'email'` otherwise.
  final String delivery;
}

/// Thin wrapper over `Api\V1\NoteCollaboratorController` — collaborator
/// lists are server-authoritative and fetched fresh, no offline caching.
class NoteCollaboratorRemoteDataSource {
  NoteCollaboratorRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<NoteCollaboratorModel>> index(String noteServerUuid) async {
    final body = await _api.get('/notes/$noteServerUuid/collaborators');

    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(NoteCollaboratorModel.fromJson)
        .toList();
  }

  Future<NoteInvitationResult> invite({
    required String noteServerUuid,
    required String email,
    required String role,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = await _api.post(
      '/notes/$noteServerUuid/collaborators',
      data: {
        'email': email,
        'role': role,
        'first_name': ?firstName,
        'last_name': ?lastName,
        'phone': ?phone,
      },
    );

    return NoteInvitationResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> updateRole({
    required String noteServerUuid,
    required String email,
    required String role,
  }) => _api.patch(
    '/notes/$noteServerUuid/collaborators/$email',
    data: {'role': role},
  );

  Future<void> remove({
    required String noteServerUuid,
    required String email,
  }) => _api.delete('/notes/$noteServerUuid/collaborators/$email');
}
