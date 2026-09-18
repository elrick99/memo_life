import '../../../core/network/api_client.dart';
import 'reminder_collaborator_model.dart';

/// Result of inviting a collaborator — mirrors the ad-hoc payload
/// `ReminderCollaboratorController::store` returns (not a `ReminderCollaboratorResource`,
/// since it also carries the one-time `invitation_url`/`delivery` fields).
class ReminderInvitationResult {
  const ReminderInvitationResult({
    required this.email,
    required this.role,
    required this.delivery,
  });

  factory ReminderInvitationResult.fromJson(Map<String, dynamic> json) =>
      ReminderInvitationResult(
        email: json['email'] as String,
        role: json['role'] as String,
        delivery: json['delivery'] as String,
      );

  final String email;
  final String role;

  /// `'in_app'` if the invitee already has an account, `'email'` otherwise.
  final String delivery;
}

/// Thin wrapper over `Api\V1\ReminderCollaboratorController` — collaborator
/// lists are server-authoritative and fetched fresh, no offline caching.
class ReminderCollaboratorRemoteDataSource {
  ReminderCollaboratorRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<ReminderCollaboratorModel>> index(
    String reminderServerUuid,
  ) async {
    final body = await _api.get(
      '/reminders/$reminderServerUuid/collaborators',
    );

    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReminderCollaboratorModel.fromJson)
        .toList();
  }

  Future<ReminderInvitationResult> invite({
    required String reminderServerUuid,
    required String email,
    required String role,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = await _api.post(
      '/reminders/$reminderServerUuid/collaborators',
      data: {
        'email': email,
        'role': role,
        'first_name': ?firstName,
        'last_name': ?lastName,
        'phone': ?phone,
      },
    );

    return ReminderInvitationResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  Future<void> updateRole({
    required String reminderServerUuid,
    required String email,
    required String role,
  }) => _api.patch(
    '/reminders/$reminderServerUuid/collaborators/$email',
    data: {'role': role},
  );

  Future<void> remove({
    required String reminderServerUuid,
    required String email,
  }) => _api.delete('/reminders/$reminderServerUuid/collaborators/$email');
}
