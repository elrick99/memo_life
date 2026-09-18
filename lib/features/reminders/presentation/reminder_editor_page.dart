import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../attachments/presentation/attachment_list.dart';
import '../../budget/presentation/widgets/category_picker.dart';
import '../../notes/data/note_model.dart';
import '../../notes/data/note_repository.dart';
import '../bloc/reminders_bloc.dart';
import '../data/reminder_model.dart';
import 'reminder_share_page.dart';

const _priorities = {
  'low': 'Faible',
  'normal': 'Normale',
  'high': 'Haute',
  'urgent': 'Urgente',
};

/// Create/edit form: [reminder] null means create. Like the note editor,
/// this writes straight to the local repository and returns immediately —
/// the sync manager pushes it in the background.
class ReminderEditorPage extends StatefulWidget {
  const ReminderEditorPage({super.key, this.reminder});

  final ReminderModel? reminder;

  @override
  State<ReminderEditorPage> createState() => _ReminderEditorPageState();
}

class _ReminderEditorPageState extends State<ReminderEditorPage> {
  late final _titleController = TextEditingController(
    text: widget.reminder?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.reminder?.description ?? '',
  );
  late DateTime _dueAt =
      widget.reminder?.dueAt ?? DateTime.now().add(const Duration(hours: 1));
  late String _type = widget.reminder?.type ?? 'task';
  late String _priority = widget.reminder?.priority ?? 'normal';
  late String _recurrence = widget.reminder?.recurrence ?? 'none';
  late String? _noteLocalUuid = widget.reminder?.noteLocalUuid;
  late String? _categoryLocalUuid = widget.reminder?.categoryLocalUuid;

  bool get _isEditing => widget.reminder != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) {
      return;
    }
    setState(
      () => _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _share() {
    final serverUuid = widget.reminder?.serverUuid;
    if (serverUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce rappel doit être synchronisé avant partage.'),
        ),
      );

      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReminderSharePage(
          reminderServerUuid: serverUuid,
          reminderTitle: widget.reminder!.title,
        ),
      ),
    );
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    final bloc = context.read<RemindersBloc>();
    if (_isEditing) {
      bloc.add(
        ReminderUpdateRequested(
          widget.reminder!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            dueAt: _dueAt,
            type: _type,
            priority: _priority,
            recurrence: _recurrence,
            noteLocalUuid: _noteLocalUuid,
            clearNote: _noteLocalUuid == null,
            categoryLocalUuid: _categoryLocalUuid,
            clearCategory: _categoryLocalUuid == null,
          ),
        ),
      );
    } else {
      bloc.add(
        ReminderCreateRequested(
          noteLocalUuid: _noteLocalUuid,
          categoryLocalUuid: _categoryLocalUuid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          dueAt: _dueAt,
          type: _type,
          priority: _priority,
          recurrence: _recurrence,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM · HH:mm', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le rappel' : 'Nouveau rappel'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.person_add_alt_rounded),
              tooltip: 'Partager',
              onPressed: _share,
            ),
          IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titre'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(dateFormat.format(_dueAt)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickDueAt,
          ),
          const SizedBox(height: 8),
          Text('Type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: reminderTypes.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) => setState(() => _type = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('Priorité', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _priorities.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _priority == entry.key,
                    onSelected: (_) => setState(() => _priority = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('Récurrence', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: reminderRecurrences.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: _recurrence == entry.key,
                    onSelected: (_) => setState(() => _recurrence = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _NotePicker(
            selectedLocalUuid: _noteLocalUuid,
            onChanged: (value) => setState(() => _noteLocalUuid = value),
          ),
          const SizedBox(height: 16),
          CategoryPicker(
            type: 'reminder',
            selectedLocalUuid: _categoryLocalUuid,
            onChanged: (value) => setState(() => _categoryLocalUuid = value),
          ),
          if (_isEditing) ...[
            const Divider(height: 32),
            AttachmentList(
              attachableType: 'reminder',
              attachableLocalUuid: widget.reminder!.localUuid,
            ),
          ],
        ],
      ),
    );
  }
}

class _NotePicker extends StatelessWidget {
  const _NotePicker({required this.selectedLocalUuid, required this.onChanged});

  final String? selectedLocalUuid;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NoteModel>>(
      future: getIt<NoteRepository>().getNotes(),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? const [];

        return DropdownButtonFormField<String?>(
          initialValue: selectedLocalUuid,
          decoration: const InputDecoration(
            labelText: 'Lier à une note (optionnel)',
          ),
          items: [
            const DropdownMenuItem<String?>(child: Text('Aucune')),
            ...notes.map(
              (note) => DropdownMenuItem<String?>(
                value: note.localUuid,
                child: Text(
                  note.title.isEmpty ? 'Sans titre' : note.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
