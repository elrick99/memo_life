import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_icons.dart';
import '../../../core/widgets/empty_state.dart';
import '../bloc/categories_bloc.dart';
import '../data/category_model.dart';
import 'widgets/icon_color_picker.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      body: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) {
          if (state.categories.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: 'Aucune catégorie pour le moment',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<CategoriesBloc>().add(
              const CategoriesRefreshRequested(),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) =>
                  _CategoryTile(category: state.categories[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryCreateSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// Opens the shared category-creation sheet. `initialType` scopes the type
/// chips (e.g. locking a Note/Reminder editor's inline "+ nouvelle
/// catégorie" to that domain) while still letting the standalone
/// [CategoriesPage] offer every type.
Future<void> showCategoryCreateSheet(
  BuildContext context, {
  String? initialType,
}) {
  final bloc = context.read<CategoriesBloc>();
  final nameController = TextEditingController();
  var type = initialType ?? 'expense';
  var color = categoryColorSwatches.first;
  String? icon;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouvelle catégorie',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 16),
              if (initialType == null)
                Wrap(
                  spacing: 8,
                  children: categoryTypes.entries
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(entry.value),
                          selected: type == entry.key,
                          onSelected: (_) => setState(() => type = entry.key),
                        ),
                      )
                      .toList(),
                ),
              if (initialType == null) const SizedBox(height: 16),
              IconColorPicker(
                selectedIcon: icon,
                selectedColor: color,
                onChanged: (value) => setState(() {
                  icon = value.icon;
                  color = value.color;
                }),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }
                  bloc.add(
                    CategoryCreateRequested(
                      name: nameController.text.trim(),
                      type: type,
                      color:
                          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      icon: icon,
                    ),
                  );
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseCategoryColor(
      category.color,
      fallback: theme.colorScheme.primary,
    );

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(resolveCategoryIcon(category.icon), color: color, size: 18),
      ),
      title: Text(category.name),
      subtitle: Text(categoryTypes[category.type] ?? category.type),
      trailing: category.isSystem
          ? Chip(
              label: const Text('Système'),
              visualDensity: VisualDensity.compact,
            )
          : IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              onPressed: () => _confirmDelete(context),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<CategoriesBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette catégorie ?'),
        content: Text('« ${category.name} » sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive(context),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(CategoryDeleted(category));
    }
  }
}
