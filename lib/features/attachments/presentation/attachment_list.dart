import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../data/attachment_model.dart';
import '../data/attachment_repository.dart';

/// Attachment list + "add" action shared by the Note and Reminder editors.
/// Only usable once the parent already has a `localUuid` — i.e. in edit
/// mode, after the note/reminder has been saved at least once.
class AttachmentList extends StatefulWidget {
  const AttachmentList({
    super.key,
    required this.attachableType,
    required this.attachableLocalUuid,
  });

  final String attachableType;
  final String attachableLocalUuid;

  @override
  State<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends State<AttachmentList> {
  final _repository = getIt<AttachmentRepository>();
  List<AttachmentModel> _attachments = const [];
  StreamSubscription<void>? _subscription;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = _repository.changes.listen((_) => _load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final attachments = await _repository.getFor(
      attachableType: widget.attachableType,
      attachableLocalUuid: widget.attachableLocalUuid,
    );
    if (mounted) {
      setState(() => _attachments = attachments);
    }
  }

  Future<void> _pickAndAdd() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      final files = result?.files ?? const [];
      if (files.isEmpty || files.first.path == null) {
        return;
      }
      final file = files.first;
      await _repository.addFromFile(
        attachableType: widget.attachableType,
        attachableLocalUuid: widget.attachableLocalUuid,
        sourcePath: file.path!,
        filename: file.name,
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _open(AttachmentModel attachment) async {
    final resolved = await _repository.downloadIfNeeded(attachment);
    if (resolved.localFilePath == null || !mounted) {
      return;
    }
    if (resolved.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) =>
            Dialog(child: Image.file(File(resolved.localFilePath!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pièces jointes', style: theme.textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: _isPicking ? null : _pickAndAdd,
              icon: _isPicking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (_attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune pièce jointe',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._attachments.map(
            (attachment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                attachment.isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
              ),
              title: Text(
                attachment.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_formatSize(attachment.size)),
              onTap: () => _open(attachment),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!attachment.isSynced)
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => _repository.deleteAttachment(attachment),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes o';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}
