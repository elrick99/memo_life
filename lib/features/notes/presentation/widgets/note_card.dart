import 'package:flutter/material.dart';

import '../../../budget/presentation/widgets/category_badge.dart';
import '../../data/note_content_codec.dart';
import '../../data/note_model.dart';
import 'tag_badges.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onArchiveToggle,
    required this.onPinToggle,
  });

  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onArchiveToggle;
  final VoidCallback onPinToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = note.color != null
        ? Color(int.parse(note.color!.substring(1), radix: 16) | 0xFF000000)
        : theme.colorScheme.primary;
    final completedItems = note.checklist
        .where((item) => item.completed)
        .length;
    final contentExcerpt = NoteContentCodec.plainTextExcerpt(
      note.content,
      note.contentFormat,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.isLocked
                          ? 'Note verrouillée'
                          : (note.title.isEmpty ? 'Sans titre' : note.title),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isLocked)
                    Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  if (!note.isSynced)
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 20,
                      color: note.isPinned ? theme.colorScheme.primary : null,
                    ),
                    onPressed: onPinToggle,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      note.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 20,
                    ),
                    onPressed: onArchiveToggle,
                  ),
                ],
              ),
              if (note.isLocked) ...[
                const SizedBox(height: 4),
                Text(
                  'Contenu masqué — appuyez pour déverrouiller',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (!note.isLocked && contentExcerpt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contentExcerpt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (!note.isLocked && note.checklist.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completedItems/${note.checklist.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: note.checklistCompletionPercent / 100,
                          minHeight: 4,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!note.isLocked &&
                  (note.categoryLocalUuid != null ||
                      note.tagLocalUuids.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (note.categoryLocalUuid != null)
                      CategoryBadge(categoryLocalUuid: note.categoryLocalUuid),
                    if (note.tagLocalUuids.isNotEmpty)
                      TagBadges(tagLocalUuids: note.tagLocalUuids),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
