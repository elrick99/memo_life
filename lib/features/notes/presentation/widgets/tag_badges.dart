import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/category_icons.dart';
import '../../data/tag_model.dart';
import '../../data/tag_repository.dart';

/// Small chips resolving a note's `tagLocalUuids` FKs to their tags, used
/// by [NoteCard]. Renders nothing while there are no tags or they haven't
/// loaded yet.
class TagBadges extends StatelessWidget {
  const TagBadges({super.key, required this.tagLocalUuids});

  final List<String> tagLocalUuids;

  @override
  Widget build(BuildContext context) {
    if (tagLocalUuids.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<TagModel>>(
      future: getIt<TagRepository>().getTags(),
      builder: (context, snapshot) {
        final tags = (snapshot.data ?? const [])
            .where((tag) => tagLocalUuids.contains(tag.localUuid))
            .toList();
        if (tags.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: tags.map((tag) {
            final color = parseCategoryColor(
              tag.color,
              fallback: theme.colorScheme.primary,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag.name,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
