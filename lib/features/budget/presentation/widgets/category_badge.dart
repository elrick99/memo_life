import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/category_icons.dart';
import '../../data/category_model.dart';
import '../../data/category_repository.dart';

/// Small icon+name chip resolving a note/reminder's `categoryLocalUuid` FK
/// to its category, used by [NoteCard] and `ReminderTile`. Renders nothing
/// while there's no category or it hasn't loaded yet.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.categoryLocalUuid});

  final String? categoryLocalUuid;

  @override
  Widget build(BuildContext context) {
    final localUuid = categoryLocalUuid;
    if (localUuid == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<CategoryModel?>(
      future: getIt<CategoryRepository>().getCategory(localUuid),
      builder: (context, snapshot) {
        final category = snapshot.data;
        if (category == null) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final color = parseCategoryColor(
          category.color,
          fallback: theme.colorScheme.primary,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(resolveCategoryIcon(category.icon), size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                category.name,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}
