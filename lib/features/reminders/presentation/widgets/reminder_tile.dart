import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../budget/presentation/widgets/category_badge.dart';
import '../../data/reminder_model.dart';

const _priorityColors = {
  'low': Colors.blueGrey,
  'normal': Colors.blue,
  'high': Colors.orange,
  'urgent': Colors.red,
};

class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggleCompleted,
  });

  final ReminderModel reminder;
  final VoidCallback onTap;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor =
        _priorityColors[reminder.priority] ?? theme.colorScheme.primary;
    final dateFormat = DateFormat('d MMM · HH:mm', 'fr_FR');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: reminder.isCompleted,
          onChanged: (_) => onToggleCompleted(),
        ),
        title: Text(
          reminder.title,
          style: reminder.isCompleted
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: priorityColor),
                const SizedBox(width: 6),
                Text(
                  dateFormat.format(reminder.dueAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: reminder.isOverdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: reminder.isOverdue ? FontWeight.w600 : null,
                  ),
                ),
                if (reminder.recurrence != 'none') ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.repeat_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            if (reminder.categoryLocalUuid != null) ...[
              const SizedBox(height: 4),
              CategoryBadge(categoryLocalUuid: reminder.categoryLocalUuid),
            ],
          ],
        ),
        trailing: reminder.isSynced
            ? null
            : Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
