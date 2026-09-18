import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/accounts_bloc.dart';
import '../bloc/categories_bloc.dart';
import '../bloc/transactions_bloc.dart';
import '../data/account_model.dart';
import '../data/category_model.dart';
import '../data/transaction_model.dart';

/// Create/edit form: [transaction] null means create. Account is required;
/// destination account only applies to transfers; category is optional.
/// All three are resolved to their `server_uuid` by the repository only at
/// push time (see `TransactionRepository`), so this form only ever deals
/// in local uuids.
class TransactionEditorPage extends StatefulWidget {
  const TransactionEditorPage({super.key, this.transaction});

  final TransactionModel? transaction;

  @override
  State<TransactionEditorPage> createState() => _TransactionEditorPageState();
}

class _TransactionEditorPageState extends State<TransactionEditorPage> {
  late final _amountController = TextEditingController(
    text: widget.transaction?.amount.toStringAsFixed(0) ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.transaction?.description ?? '',
  );
  late String _type = widget.transaction?.type ?? 'expense';
  late DateTime _occurredAt = widget.transaction?.occurredAt ?? DateTime.now();
  late String? _accountLocalUuid = widget.transaction?.accountLocalUuid;
  late String? _destinationAccountLocalUuid =
      widget.transaction?.destinationAccountLocalUuid;
  late String? _categoryLocalUuid = widget.transaction?.categoryLocalUuid;

  bool get _isEditing => widget.transaction != null;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(
        () => _occurredAt = DateTime(
          date.year,
          date.month,
          date.day,
          _occurredAt.hour,
          _occurredAt.minute,
        ),
      );
    }
  }

  void _save() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0 || _accountLocalUuid == null) {
      return;
    }
    if (_type == 'transfer' && _destinationAccountLocalUuid == null) {
      return;
    }

    final bloc = context.read<TransactionsBloc>();
    if (_isEditing) {
      bloc.add(
        TransactionUpdateRequested(
          widget.transaction!.copyWith(
            accountLocalUuid: _accountLocalUuid,
            destinationAccountLocalUuid: _type == 'transfer'
                ? _destinationAccountLocalUuid
                : null,
            clearDestinationAccount: _type != 'transfer',
            categoryLocalUuid: _categoryLocalUuid,
            clearCategory: _categoryLocalUuid == null,
            type: _type,
            amount: amount,
            occurredAt: _occurredAt,
            description: _descriptionController.text.trim(),
          ),
        ),
      );
    } else {
      bloc.add(
        TransactionCreateRequested(
          accountLocalUuid: _accountLocalUuid!,
          destinationAccountLocalUuid: _type == 'transfer'
              ? _destinationAccountLocalUuid
              : null,
          categoryLocalUuid: _categoryLocalUuid,
          type: _type,
          amount: amount,
          occurredAt: _occurredAt,
          description: _descriptionController.text.trim(),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountsBloc>().state.accounts;
    final categories = context.watch<CategoriesBloc>().state.categories.where(
      (c) => c.type == _type || _type == 'transfer',
    );
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier la transaction' : 'Nouvelle transaction',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: transactionTypes.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) => setState(() {
                      _type = entry.key;
                      if (_type != 'transfer') {
                        _destinationAccountLocalUuid = null;
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant'),
          ),
          const SizedBox(height: 16),
          _AccountDropdown(
            label: 'Compte',
            accounts: accounts,
            value: _accountLocalUuid,
            onChanged: (value) => setState(() => _accountLocalUuid = value),
          ),
          if (_type == 'transfer') ...[
            const SizedBox(height: 16),
            _AccountDropdown(
              label: 'Compte destinataire',
              accounts: accounts
                  .where((a) => a.localUuid != _accountLocalUuid)
                  .toList(),
              value: _destinationAccountLocalUuid,
              onChanged: (value) =>
                  setState(() => _destinationAccountLocalUuid = value),
            ),
          ],
          if (_type != 'transfer') ...[
            const SizedBox(height: 16),
            _CategoryDropdown(
              categories: categories.toList(),
              value: _categoryLocalUuid,
              onChanged: (value) => setState(() => _categoryLocalUuid = value),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(dateFormat.format(_occurredAt)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<AccountModel> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: accounts.any((a) => a.localUuid == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: accounts
          .map(
            (account) => DropdownMenuItem<String?>(
              value: account.localUuid,
              child: Text(account.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<CategoryModel> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: categories.any((c) => c.localUuid == value) ? value : null,
      decoration: const InputDecoration(labelText: 'Catégorie (optionnel)'),
      items: [
        const DropdownMenuItem<String?>(child: Text('Aucune')),
        ...categories.map(
          (category) => DropdownMenuItem<String?>(
            value: category.localUuid,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
