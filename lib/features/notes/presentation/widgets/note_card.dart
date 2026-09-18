import 'package:flutter/material.dart';

import '../../../budget/presentation/widgets/category_badge.dart';
import '../../data/note_model.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onArchiveToggle,
  });

  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = note.color != null
        ? Color(int.parse(note.color!.substring(1), radix: 16) | 0xFF000000)
        : theme.colorScheme.primary;
    final completedItems = note.checklist
        .where((item) => item.completed)
        .length;

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
                      note.title.isEmpty ? 'Sans titre' : note.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      note.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 20,
                    ),
                    onPressed: onArchiveToggle,
                  ),
                ],
              ),
              if ((note.content ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  note.content!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (note.checklist.isNotEmpty) ...[
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
                  ],
                ),
              ],
              if (note.categoryLocalUuid != null) ...[
                const SizedBox(height: 8),
                CategoryBadge(categoryLocalUuid: note.categoryLocalUuid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
