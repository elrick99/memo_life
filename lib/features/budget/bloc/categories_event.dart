part of 'categories_bloc.dart';

sealed class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

class CategoriesSubscriptionRequested extends CategoriesEvent {
  const CategoriesSubscriptionRequested();
}

class CategoriesListUpdated extends CategoriesEvent {
  const CategoriesListUpdated(this.categories);

  final List<CategoryModel> categories;

  @override
  List<Object?> get props => [categories];
}

class CategoriesRefreshRequested extends CategoriesEvent {
  const CategoriesRefreshRequested();
}

class CategoryCreateRequested extends CategoriesEvent {
  const CategoryCreateRequested({
    required this.name,
    this.type = 'expense',
    this.color,
    this.icon,
  });

  final String name;
  final String type;
  final String? color;
  final String? icon;

  @override
  List<Object?> get props => [name, type, color, icon];
}

class CategoryDeleted extends CategoriesEvent {
  const CategoryDeleted(this.category);

  final CategoryModel category;

  @override
  List<Object?> get props => [category];
}
