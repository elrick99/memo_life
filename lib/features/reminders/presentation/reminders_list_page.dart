import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../bloc/reminders_bloc.dart';
import '../data/reminder_model.dart';
import 'reminder_editor_page.dart';
import 'reminders_timeline_page.dart';
import 'widgets/reminder_tile.dart';

class RemindersListPage extends StatefulWidget {
  const RemindersListPage({super.key});

  @override
  State<RemindersListPage> createState() => _RemindersListPageState();
}

class _RemindersListPageState extends State<RemindersListPage> {
  @override
  void initState() {
    super.initState();
    context.read<RemindersBloc>().add(const RemindersSubscriptionRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Rappels',
        icon: Icons.alarm_rounded,
        actions: [
          IconButton(
            tooltip: 'Vue agenda',
            icon: const Icon(Icons.view_timeline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<RemindersBloc>(),
                  child: const RemindersTimelinePage(),
                ),
              ),
            ),
          ),
          BlocBuilder<RemindersBloc, RemindersState>(
            buildWhen: (previous, current) =>
                previous.showCompleted != current.showCompleted,
            builder: (context, state) => IconButton(
              tooltip: state.showCompleted
                  ? 'Voir les rappels à venir'
                  : 'Voir les rappels terminés',
              icon: Icon(
                state.showCompleted
                    ? Icons.pending_actions_rounded
                    : Icons.done_all_rounded,
              ),
              onPressed: () => context.read<RemindersBloc>().add(
                const RemindersCompletedFilterToggled(),
              ),
            ),
          ),
          const SyncStatusChip(),
        ],
      ),
      body: BlocBuilder<RemindersBloc, RemindersState>(
        builder: (context, state) {
          if (state.status == RemindersStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final reminders = state.visibleReminders;

          return RefreshIndicator(
            onRefresh: () async => context.read<RemindersBloc>().add(
              const RemindersRefreshRequested(),
            ),
            child: reminders.isEmpty
                ? ListView(
                    children: [
                      EmptyState(
                        icon: Icons.alarm_rounded,
                        title: state.showCompleted
                            ? 'Aucun rappel terminé'
                            : 'Aucun rappel pour le moment',
                        subtitle: state.showCompleted
                            ? null
                            : 'Appuyez sur + pour créer votre premier rappel.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reminders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ReminderListItem(reminder: reminders[index]),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: context.read<RemindersBloc>(),
              child: const ReminderEditorPage(),
            ),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _ReminderListItem extends StatelessWidget {
  const _ReminderListItem({required this.reminder});

  final ReminderModel reminder;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RemindersBloc>();

    return Dismissible(
      key: ValueKey(reminder.localUuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer ce rappel ?'),
          content: Text('« ${reminder.title} » sera définitivement supprimé.'),
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
      ),
      onDismissed: (_) => bloc.add(ReminderDeleted(reminder)),
      child: ReminderTile(
        reminder: reminder,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: ReminderEditorPage(reminder: reminder),
            ),
          ),
        ),
        onToggleCompleted: () => bloc.add(ReminderCompletedToggled(reminder)),
        onPinToggle: () => bloc.add(ReminderPinToggled(reminder)),
      ),
    );
  }
}
