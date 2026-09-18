import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/accounts_bloc.dart';
import '../data/account_model.dart';

/// Create/edit bottom sheet: [account] null means create. Balance is only
/// editable at creation — afterwards it's derived from transactions (see
/// `TransactionRepository`), matching how the backend treats it.
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key, this.account});

  final AccountModel? account;

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  late final _nameController = TextEditingController(
    text: widget.account?.name ?? '',
  );
  late final _balanceController = TextEditingController(
    text: widget.account == null
        ? '0'
        : widget.account!.balance.toStringAsFixed(0),
  );
  late String _type = widget.account?.type ?? 'cash';

  bool get _isEditing => widget.account != null;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      return;
    }
    final bloc = context.read<AccountsBloc>();
    if (_isEditing) {
      bloc.add(
        AccountUpdateRequested(
          widget.account!.copyWith(
            name: _nameController.text.trim(),
            type: _type,
          ),
        ),
      );
    } else {
      bloc.add(
        AccountCreateRequested(
          name: _nameController.text.trim(),
          type: _type,
          balance: double.tryParse(_balanceController.text) ?? 0,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Modifier le compte' : 'Nouveau compte',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: accountTypes.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                  )
                  .toList(),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Solde initial'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Enregistrer')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
