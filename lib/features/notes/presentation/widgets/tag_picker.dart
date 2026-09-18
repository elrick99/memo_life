import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/category_icons.dart';
import '../../data/tag_model.dart';
import '../../data/tag_repository.dart';

/// Multi-select tag chips, with an inline "+ nouvelle étiquette" action —
/// reused wherever a note needs to be tagged.
class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.selectedLocalUuids,
    required this.onChanged,
  });

  final List<String> selectedLocalUuids;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  late Future<List<TagModel>> _future = getIt<TagRepository>().getTags();

  void _toggle(String localUuid) {
    final selected = List.of(widget.selectedLocalUuids);
    if (selected.contains(localUuid)) {
      selected.remove(localUuid);
    } else {
      selected.add(localUuid);
    }
    widget.onChanged(selected);
  }

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    var color = categoryColorSwatches.first;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Nouvelle étiquette'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: categoryColorSwatches
                    .map(
                      (swatch) => GestureDetector(
                        onTap: () => setState(() => color = swatch),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: swatch,
                          child: color == swatch
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (created != true || nameController.text.trim().isEmpty || !mounted) {
      return;
    }
    final tag = await getIt<TagRepository>().createTag(
      name: nameController.text.trim(),
      color:
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
    if (!mounted) {
      return;
    }
    setState(() => _future = getIt<TagRepository>().getTags());
    widget.onChanged([...widget.selectedLocalUuids, tag.localUuid]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TagModel>>(
      future: _future,
      builder: (context, snapshot) {
        final tags = snapshot.data ?? const [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Étiquettes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...tags.map(
                  (tag) => FilterChip(
                    label: Text(tag.name),
                    selected: widget.selectedLocalUuids.contains(tag.localUuid),
                    onSelected: (_) => _toggle(tag.localUuid),
                    avatar: CircleAvatar(
                      backgroundColor: parseCategoryColor(
                        tag.color,
                        fallback: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nouvelle'),
                  onPressed: _openCreateDialog,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
