import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_chip.dart';
import '../bloc/notes_bloc.dart';
import '../data/note_model.dart';
import 'note_editor_page.dart';
import 'widgets/note_card.dart';

class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(const NotesSubscriptionRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Notes',
        icon: Icons.notes_rounded,
        actions: [
          BlocBuilder<NotesBloc, NotesState>(
            buildWhen: (previous, current) =>
                previous.showArchived != current.showArchived,
            builder: (context, state) => IconButton(
              tooltip: state.showArchived
                  ? 'Voir les notes actives'
                  : 'Voir les archives',
              icon: Icon(
                state.showArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              onPressed: () => context.read<NotesBloc>().add(
                const NotesArchivedFilterToggled(),
              ),
            ),
          ),
          const SyncStatusChip(),
        ],
      ),
      body: BlocBuilder<NotesBloc, NotesState>(
        builder: (context, state) {
          if (state.status == NotesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = state.visibleNotes;

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<NotesBloc>().add(const NotesRefreshRequested()),
            child: notes.isEmpty
                ? ListView(
                    children: [
                      EmptyState(
                        icon: Icons.notes_rounded,
                        title: state.showArchived
                            ? 'Aucune note archivée'
                            : 'Aucune note pour le moment',
                        subtitle: state.showArchived
                            ? null
                            : 'Appuyez sur + pour créer votre première note.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _NoteListItem(note: notes[index]),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: context.read<NotesBloc>(),
              child: const NoteEditorPage(),
            ),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  const _NoteListItem({required this.note});

  final NoteModel note;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotesBloc>();

    return Dismissible(
      key: ValueKey(note.localUuid),
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
          title: const Text('Supprimer cette note ?'),
          content: Text('« ${note.title} » sera définitivement supprimée.'),
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
      onDismissed: (_) => bloc.add(NoteDeleted(note)),
      child: NoteCard(
        note: note,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: NoteEditorPage(note: note),
            ),
          ),
        ),
        onArchiveToggle: () => bloc.add(NoteArchiveToggled(note)),
      ),
    );
  }
}
