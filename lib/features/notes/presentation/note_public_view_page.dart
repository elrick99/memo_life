import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_exception.dart';
import '../data/note_public_remote_data_source.dart';

/// Read-only viewer reached via the note share deep link
/// (`/notes/shared/{token}`, opened through Universal Links/App Links or the
/// `memolife://` custom scheme) — works with or without an account, since
/// the underlying endpoint is unauthenticated. See `app.dart`'s router
/// `redirect` for the exemption that lets this route bypass the login gate.
class NotePublicViewPage extends StatefulWidget {
  const NotePublicViewPage({super.key, required this.token});

  final String token;

  @override
  State<NotePublicViewPage> createState() => _NotePublicViewPageState();
}

class _NotePublicViewPageState extends State<NotePublicViewPage> {
  final _remote = getIt<NotePublicRemoteDataSource>();
  NotePublicView? _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final note = await _remote.show(widget.token);
      if (mounted) {
        setState(() => _note = note);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = _note;
    final error = _error;

    return Scaffold(
      appBar: AppBar(title: const Text('Note partagée')),
      body: switch (note) {
        null when error != null => Center(child: Text(error)),
        null => const Center(child: CircularProgressIndicator()),
        _ => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                (note.title?.isEmpty ?? true) ? 'Sans titre' : note.title!,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (note.content != null && note.content!.isNotEmpty)
                Text(note.content!),
              if (note.checklist.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...note.checklist.map(
                  (item) => CheckboxListTile(
                    value: item.completed,
                    onChanged: null,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.text),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Lecture seule — partagé via un lien.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      },
    );
  }
}
