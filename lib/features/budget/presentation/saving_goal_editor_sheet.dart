import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/saving_goals_bloc.dart';
import '../data/saving_goal_model.dart';

class SavingGoalEditorSheet extends StatefulWidget {
  const SavingGoalEditorSheet({super.key, this.goal});

  final SavingGoalModel? goal;

  @override
  State<SavingGoalEditorSheet> createState() => _SavingGoalEditorSheetState();
}

class _SavingGoalEditorSheetState extends State<SavingGoalEditorSheet> {
  late final _nameController = TextEditingController(
    text: widget.goal?.name ?? '',
  );
  late final _targetController = TextEditingController(
    text: widget.goal?.targetAmount.toStringAsFixed(0) ?? '',
  );
  late final _currentController = TextEditingController(
    text: widget.goal?.currentAmount.toStringAsFixed(0) ?? '0',
  );
  DateTime? _targetDate;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _targetDate = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() => _targetDate = date);
    }
  }

  void _save() {
    final target = double.tryParse(_targetController.text);
    if (_nameController.text.trim().isEmpty || target == null || target <= 0) {
      return;
    }
    final bloc = context.read<SavingGoalsBloc>();
    final current = double.tryParse(_currentController.text) ?? 0;
    if (_isEditing) {
      bloc.add(
        SavingGoalUpdateRequested(
          widget.goal!.copyWith(
            name: _nameController.text.trim(),
            targetAmount: target,
            currentAmount: current,
            targetDate: _targetDate,
            clearTargetDate: _targetDate == null,
          ),
        ),
      );
    } else {
      bloc.add(
        SavingGoalCreateRequested(
          name: _nameController.text.trim(),
          targetAmount: target,
          currentAmount: current,
          targetDate: _targetDate,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');

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
              _isEditing ? 'Modifier l\'objectif' : 'Nouvel objectif',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant cible'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _currentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Montant actuel'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(
                _targetDate == null
                    ? 'Date cible (optionnel)'
                    : dateFormat.format(_targetDate!),
              ),
              trailing: _targetDate != null
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _targetDate = null),
                    )
                  : null,
              onTap: _pickTargetDate,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Enregistrer')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
