import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/invite_contact_dialog.dart';
import '../data/reminder_collaborator_model.dart';
import '../data/reminder_collaborator_remote_data_source.dart';

const _roles = {'editor': 'Peut modifier', 'viewer': 'Lecture seule'};

String _subtitle(ReminderCollaboratorModel collaborator) {
  final parts = [collaborator.email];
  if (collaborator.invitedEmail != null &&
      collaborator.invitedEmail != collaborator.email) {
    parts.add('invité avec ${collaborator.invitedEmail}');
  }
  if (collaborator.phone != null) {
    parts.add(collaborator.phone!);
  }

  return parts.join(' · ');
}

/// Manage who a reminder is shared with. Only reachable from the reminder's
/// own owner today (a collaborated-on reminder doesn't yet appear in the
/// invitee's local list — see `ReminderController::index`), so every
/// non-owner row here is someone already invited by the current user.
class ReminderSharePage extends StatefulWidget {
  const ReminderSharePage({
    super.key,
    required this.reminderServerUuid,
    required this.reminderTitle,
  });

  final String reminderServerUuid;
  final String reminderTitle;

  @override
  State<ReminderSharePage> createState() => _ReminderSharePageState();
}

class _ReminderSharePageState extends State<ReminderSharePage> {
  final _remote = getIt<ReminderCollaboratorRemoteDataSource>();
  List<ReminderCollaboratorModel> _collaborators = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final collaborators = await _remote.index(widget.reminderServerUuid);
      if (mounted) {
        setState(() {
          _collaborators = collaborators;
          _isLoading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(error.message);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _invite() async {
    final result = await showInviteContactDialog(context, roles: _roles);
    if (result == null) {
      return;
    }
    try {
      final invitation = await _remote.invite(
        reminderServerUuid: widget.reminderServerUuid,
        email: result.email,
        role: result.role,
        firstName: result.firstName,
        lastName: result.lastName,
        phone: result.phone,
      );
      if (!mounted) {
        return;
      }
      _showError(
        invitation.delivery == 'in_app'
            ? '${invitation.email} a été notifié dans l\'application.'
            : 'Une invitation a été envoyée par e-mail à ${invitation.email}.',
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _changeRole(
    ReminderCollaboratorModel collaborator,
    String role,
  ) async {
    try {
      await _remote.updateRole(
        reminderServerUuid: widget.reminderServerUuid,
        email: collaborator.email,
        role: role,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _remove(ReminderCollaboratorModel collaborator) async {
    try {
      await _remote.remove(
        reminderServerUuid: widget.reminderServerUuid,
        email: collaborator.email,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Partager « ${widget.reminderTitle} »'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded),
            onPressed: _invite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _collaborators
                    .map(
                      (collaborator) => ListTile(
                        title: Text(collaborator.name),
                        subtitle: Text(_subtitle(collaborator)),
                        trailing: collaborator.isOwner
                            ? Text(
                                'Propriétaire',
                                style: theme.textTheme.bodySmall,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButton<String>(
                                    value: collaborator.role,
                                    underline: const SizedBox.shrink(),
                                    items: _roles.entries
                                        .map(
                                          (entry) => DropdownMenuItem(
                                            value: entry.key,
                                            child: Text(entry.value),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (role) => role == null
                                        ? null
                                        : _changeRole(collaborator, role),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: theme.colorScheme.error,
                                    ),
                                    onPressed: () => _remove(collaborator),
                                  ),
                                ],
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
