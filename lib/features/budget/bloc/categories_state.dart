part of 'categories_bloc.dart';

enum CategoriesStatus { initial, loading, ready }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
  });

  final CategoriesStatus status;
  final List<CategoryModel> categories;

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<CategoryModel>? categories,
  }) => CategoriesState(
    status: status ?? this.status,
    categories: categories ?? this.categories,
  );

  @override
  List<Object?> get props => [status, categories];
}
