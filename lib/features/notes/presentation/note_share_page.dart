import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_exception.dart';
import '../data/note_share_link_model.dart';
import '../data/note_share_link_remote_data_source.dart';

/// Manage the note's public read-only link. The raw URL is only ever known
/// right after creation (`NoteShareLinkController::store`) — reopening this
/// page later only confirms a link is active, it can't show the same URL
/// again, so "regenerate" is the only way to get a fresh one.
class NoteSharePage extends StatefulWidget {
  const NoteSharePage({
    super.key,
    required this.noteServerUuid,
    required this.noteTitle,
  });

  final String noteServerUuid;
  final String noteTitle;

  @override
  State<NoteSharePage> createState() => _NoteSharePageState();
}

class _NoteSharePageState extends State<NoteSharePage> {
  final _remote = getIt<NoteShareLinkRemoteDataSource>();
  NoteShareLinkModel? _link;
  bool _isLoading = true;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final link = await _remote.current(widget.noteServerUuid);
      if (mounted) {
        setState(() {
          _link = link;
          _isLoading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(error.message);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createOrRegenerate() async {
    setState(() => _isWorking = true);
    try {
      final link = await _remote.create(widget.noteServerUuid);
      if (mounted) {
        setState(() {
          _link = link;
          _isWorking = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
        _showMessage(error.message);
      }
    }
  }

  Future<void> _revoke() async {
    setState(() => _isWorking = true);
    try {
      await _remote.revoke(widget.noteServerUuid);
      if (mounted) {
        setState(() {
          _link = null;
          _isWorking = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
        _showMessage(error.message);
      }
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      _showMessage('Lien copié.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Partager « ${widget.noteTitle} »')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Toute personne avec ce lien peut lire cette note, avec ou sans l\'application.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (_link?.url != null) ...[
                  SelectableText(_link!.url!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _copy(_link!.url!),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier le lien'),
                  ),
                  const SizedBox(height: 24),
                ] else if (_link != null) ...[
                  Text(
                    'Un lien de partage est actif. Pour le récupérer, régénérez-le.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                ],
                FilledButton.tonalIcon(
                  onPressed: _isWorking ? null : _createOrRegenerate,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(
                    _link == null ? 'Créer un lien de partage' : 'Régénérer',
                  ),
                ),
                if (_link != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isWorking ? null : _revoke,
                    icon: Icon(
                      Icons.link_off_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Révoquer le lien',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
