import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// What the user filled in — either picked from the phone's address book or
/// typed manually — to invite someone to a note or reminder.
class InviteContactResult {
  const InviteContactResult({
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phone,
  });

  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? phone;
}

/// Dialog for inviting a collaborator, either by picking a phone contact or
/// entering their details manually (prénom, nom, e-mail, téléphone). [roles]
/// maps role keys (e.g. `'editor'`) to their display label.
Future<InviteContactResult?> showInviteContactDialog(
  BuildContext context, {
  required Map<String, String> roles,
}) => showDialog<InviteContactResult>(
  context: context,
  builder: (_) => _InviteContactDialog(roles: roles),
);

class _InviteContactDialog extends StatefulWidget {
  const _InviteContactDialog({required this.roles});

  final Map<String, String> roles;

  @override
  State<_InviteContactDialog> createState() => _InviteContactDialogState();
}

class _InviteContactDialogState extends State<_InviteContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  late String _role = widget.roles.keys.first;
  bool _isPickingContact = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    setState(() => _isPickingContact = true);
    try {
      // showPicker() itself needs no permission on iOS, but Android requires
      // READ_CONTACTS to return anything beyond id/displayName.
      if (Platform.isAndroid) {
        final status = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Autorisation d\'accès aux contacts refusée.'),
              ),
            );
          }

          return;
        }
      }
      final contact = await FlutterContacts.native.showPicker(
        properties: const {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
      );
      if (contact == null) {
        return;
      }
      setState(() {
        _firstNameController.text = contact.name?.first ?? '';
        _lastNameController.text = contact.name?.last ?? '';
        if (contact.emails.isNotEmpty) {
          _emailController.text = contact.emails.first.address;
        }
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first.number;
        }
      });
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Impossible d\'ouvrir les contacts.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingContact = false);
      }
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    Navigator.of(context).pop(
      InviteContactResult(
        email: _emailController.text.trim(),
        role: _role,
        firstName: firstName.isEmpty ? null : firstName,
        lastName: lastName.isEmpty ? null : lastName,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inviter quelqu\'un'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _isPickingContact ? null : _pickContact,
                icon: _isPickingContact
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.contacts_outlined),
                label: const Text('Choisir un contact'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'E-mail invalide.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: widget.roles.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Text(entry.value),
                        selected: _role == entry.key,
                        onSelected: (_) => setState(() => _role = entry.key),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Inviter')),
      ],
    );
  }
}
