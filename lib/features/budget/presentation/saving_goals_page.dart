import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/saving_goals_bloc.dart';
import '../data/saving_goal_model.dart';
import 'saving_goal_editor_sheet.dart';

class SavingGoalsPage extends StatelessWidget {
  const SavingGoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objectifs d\'épargne')),
      body: BlocBuilder<SavingGoalsBloc, SavingGoalsState>(
        builder: (context, state) {
          if (state.goals.isEmpty) {
            return const EmptyState(
              icon: Icons.savings_outlined,
              title: 'Aucun objectif pour le moment',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<SavingGoalsBloc>().add(
              const SavingGoalsRefreshRequested(),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.goals.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _GoalCard(goal: state.goals[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: context.read<SavingGoalsBloc>(),
            child: const SavingGoalEditorSheet(),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final SavingGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<SavingGoalsBloc>();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: SavingGoalEditorSheet(goal: goal),
          ),
        ),
        onLongPress: () => _confirmDelete(context, bloc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(goal.name, style: theme.textTheme.titleMedium),
                  ),
                  if (!goal.isSynced)
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(goal.progress * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SavingGoalsBloc bloc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet objectif ?'),
        content: Text('« ${goal.name} » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive(context),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(SavingGoalDeleted(goal));
    }
  }
}
