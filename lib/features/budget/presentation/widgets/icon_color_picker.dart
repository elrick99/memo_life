import 'package:flutter/material.dart';

import '../../../../core/theme/category_icons.dart';

/// Icon grid + color swatch row shared by the category-creation sheets in
/// Budget, Notes and Reminders, so a category looks the same everywhere it's
/// picked or displayed.
class IconColorPicker extends StatelessWidget {
  const IconColorPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onChanged,
  });

  final String? selectedIcon;
  final Color selectedColor;
  final ValueChanged<({String icon, Color color})> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Couleur', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categoryColorSwatches.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final color = categoryColorSwatches[index];
              final isSelected = color.toARGB32() == selectedColor.toARGB32();

              return GestureDetector(
                onTap: () =>
                    onChanged((icon: selectedIcon ?? 'tag', color: color)),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Icône', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: categoryIcons.length,
            itemBuilder: (context, index) {
              final entry = categoryIcons.entries.elementAt(index);
              final isSelected = entry.key == selectedIcon;

              return GestureDetector(
                onTap: () => onChanged((icon: entry.key, color: selectedColor)),
                child: CircleAvatar(
                  backgroundColor: isSelected
                      ? selectedColor
                      : selectedColor.withValues(alpha: 0.12),
                  child: Icon(
                    entry.value,
                    color: isSelected ? Colors.white : selectedColor,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
