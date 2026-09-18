import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/category_icons.dart';
import '../../data/category_model.dart';
import '../../data/category_repository.dart';
import '../categories_page.dart';

/// Category dropdown scoped to one [type] (`'note'` or `'reminder'`), with
/// an inline "+ nouvelle catégorie" action that opens the same creation
/// sheet Budget uses — reused by the Note and Reminder editors.
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({
    super.key,
    required this.type,
    required this.selectedLocalUuid,
    required this.onChanged,
  });

  final String type;
  final String? selectedLocalUuid;
  final ValueChanged<String?> onChanged;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  late Future<List<CategoryModel>> _future = _load();

  Future<List<CategoryModel>> _load() async {
    final categories = await getIt<CategoryRepository>().getCategories();

    return categories
        .where((category) => category.type == widget.type)
        .toList();
  }

  Future<void> _openCreateSheet() async {
    await showCategoryCreateSheet(context, initialType: widget.type);
    if (mounted) {
      setState(() => _future = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<CategoryModel>>(
      future: _future,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const [];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: widget.selectedLocalUuid,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('Aucune')),
                  ...categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.localUuid,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            resolveCategoryIcon(category.icon),
                            size: 16,
                            color: parseCategoryColor(
                              category.color,
                              fallback: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: widget.onChanged,
              ),
            ),
            IconButton(
              tooltip: 'Nouvelle catégorie',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: _openCreateSheet,
            ),
          ],
        );
      },
    );
  }
}
