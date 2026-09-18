import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:laravel_reverb/laravel_reverb.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/realtime/reverb_client.dart';
import '../../attachments/presentation/attachment_list.dart';
import '../../budget/presentation/widgets/category_picker.dart';
import '../bloc/notes_bloc.dart';
import '../data/checklist_item.dart';
import '../data/note_model.dart';
import '../data/note_realtime_remote_data_source.dart';
import '../data/note_remote_data_source.dart';
import 'note_collaborators_page.dart';
import 'note_share_page.dart';

const _priorities = {
  'low': 'Faible',
  'normal': 'Normale',
  'high': 'Haute',
  'urgent': 'Urgente',
};

/// Create/edit form: [note] null means create. Saves straight to the local
/// repository (offline-first — the Bloc/repository push in the background),
/// so this page never blocks on the network.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note});

  final NoteModel? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final _titleController = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final _contentController = TextEditingController(
    text: widget.note?.content ?? '',
  );
  late final _newChecklistItemController = TextEditingController();
  late String _priority = widget.note?.priority ?? 'normal';
  late List<ChecklistItem> _checklist = List.of(
    widget.note?.checklist ?? const [],
  );
  late String? _categoryLocalUuid = widget.note?.categoryLocalUuid;

  Subscription? _realtimeSubscription;
  Timer? _realtimePushDebounce;
  DateTime? _lastKnownUpdatedAt;

  bool get _isEditing => widget.note != null;

  /// Live editing only makes sense once the note has a server identity and
  /// no local edit is still waiting to be pushed — mixing the offline-first
  /// queue with the realtime conflict check on the same note at once would
  /// make "last known updated_at" ambiguous.
  bool get _supportsRealtime =>
      _isEditing && widget.note!.serverUuid != null && widget.note!.isSynced;

  @override
  void initState() {
    super.initState();
    if (_supportsRealtime) {
      _lastKnownUpdatedAt = widget.note!.updatedAt;
      _contentController.addListener(_scheduleRealtimePush);
      _subscribeToRealtimeUpdates();
    }
  }

  @override
  void dispose() {
    _realtimePushDebounce?.cancel();
    _realtimeSubscription?.cancel();
    _contentController.removeListener(_scheduleRealtimePush);
    _titleController.dispose();
    _contentController.dispose();
    _newChecklistItemController.dispose();
    super.dispose();
  }

  Future<void> _subscribeToRealtimeUpdates() async {
    final reverbClient = getIt<ReverbClient>();
    await reverbClient.connect();
    if (!mounted) {
      return;
    }
    final channel = reverbClient.instance.presence(
      'notes.${widget.note!.serverUuid}',
    );
    _realtimeSubscription = channel.listen(
      '.note.content-updated',
      _onRemoteContentUpdated,
    );
  }

  void _onRemoteContentUpdated(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }
    setState(() {
      _contentController.text = data['content'] as String? ?? '';
      _checklist = (data['checklist'] as List<dynamic>? ?? const [])
          .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
          .toList();
    });
    _lastKnownUpdatedAt = DateTime.parse(data['updated_at'] as String);
  }

  void _scheduleRealtimePush() {
    _realtimePushDebounce?.cancel();
    _realtimePushDebounce = Timer(
      const Duration(seconds: 2),
      _pushRealtimeUpdate,
    );
  }

  Future<void> _pushRealtimeUpdate() async {
    final serverUuid = widget.note?.serverUuid;
    final lastKnownUpdatedAt = _lastKnownUpdatedAt;
    if (serverUuid == null || lastKnownUpdatedAt == null) {
      return;
    }
    try {
      final result = await getIt<NoteRealtimeRemoteDataSource>().push(
        noteServerUuid: serverUuid,
        content: _contentController.text,
        checklist: _checklist,
        lastKnownUpdatedAt: lastKnownUpdatedAt,
      );
      _lastKnownUpdatedAt = result.updatedAt;
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        await _resolveRealtimeConflict(serverUuid);
      }
    }
  }

  /// A 409 means someone else's edit landed first — the exception itself
  /// doesn't carry the response body (see [ApiClient]'s single-error-type
  /// design), so this re-fetches the note to recover the current content.
  Future<void> _resolveRealtimeConflict(String serverUuid) async {
    try {
      final json = await getIt<NoteRemoteDataSource>().show(serverUuid);
      if (!mounted) {
        return;
      }
      final update = NoteRealtimeUpdate.fromJson(json);
      setState(() {
        _contentController.text = update.content ?? '';
        _checklist = update.checklist;
      });
      _lastKnownUpdatedAt = update.updatedAt;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un collaborateur a modifié cette note.'),
        ),
      );
    } on ApiException {
      // Give up silently — the next debounced push retries with whatever
      // the user types next, using the (still stale) updated_at it has.
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      Navigator.of(context).pop();

      return;
    }

    final bloc = context.read<NotesBloc>();
    if (_isEditing) {
      bloc.add(
        NoteUpdateRequested(
          widget.note!.copyWith(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            checklist: _checklist,
            priority: _priority,
            categoryLocalUuid: _categoryLocalUuid,
            clearCategory: _categoryLocalUuid == null,
          ),
        ),
      );
    } else {
      bloc.add(
        NoteCreateRequested(
          categoryLocalUuid: _categoryLocalUuid,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          checklist: _checklist,
          priority: _priority,
        ),
      );
    }
    Navigator.of(context).pop();
  }

  void _share() {
    final serverUuid = widget.note?.serverUuid;
    if (serverUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette note doit être synchronisée avant partage.'),
        ),
      );

      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NoteSharePage(
          noteServerUuid: serverUuid,
          noteTitle: widget.note!.title,
        ),
      ),
    );
  }

  void _manageCollaborators() {
    final serverUuid = widget.note?.serverUuid;
    if (serverUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cette note doit être synchronisée avant d\'inviter quelqu\'un.',
          ),
        ),
      );

      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NoteCollaboratorsPage(
          noteServerUuid: serverUuid,
          noteTitle: widget.note!.title,
        ),
      ),
    );
  }

  void _addChecklistItem() {
    final text = _newChecklistItemController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _checklist = [..._checklist, ChecklistItem(text: text, completed: false)];
      _newChecklistItemController.clear();
    });
    _scheduleRealtimePush();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la note' : 'Nouvelle note'),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_rounded),
              tooltip: 'Collaborateurs',
              onPressed: _manageCollaborators,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Partager',
              onPressed: _share,
            ),
          ],
          IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'Titre',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Écrivez quelque chose…',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
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
          CategoryPicker(
            type: 'note',
            selectedLocalUuid: _categoryLocalUuid,
            onChanged: (value) => setState(() => _categoryLocalUuid = value),
          ),
          const Divider(height: 32),
          Text(
            'Liste de tâches',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._checklist.asMap().entries.map(
            (entry) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: entry.value.completed,
              title: Text(entry.value.text),
              onChanged: (checked) {
                setState(() {
                  _checklist = [..._checklist]
                    ..[entry.key] = entry.value.copyWith(
                      completed: checked ?? false,
                    );
                });
                _scheduleRealtimePush();
              },
              secondary: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(
                    () => _checklist = [..._checklist]..removeAt(entry.key),
                  );
                  _scheduleRealtimePush();
                },
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newChecklistItemController,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter un élément',
                  ),
                  onSubmitted: (_) => _addChecklistItem(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _addChecklistItem,
              ),
            ],
          ),
          if (_isEditing) ...[
            const Divider(height: 32),
            AttachmentList(
              attachableType: 'note',
              attachableLocalUuid: widget.note!.localUuid,
            ),
          ],
        ],
      ),
    );
  }
}
