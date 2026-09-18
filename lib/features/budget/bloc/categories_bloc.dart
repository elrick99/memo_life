import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/category_model.dart';
import '../data/category_repository.dart';

part 'categories_event.dart';
part 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc({required this._repository}) : super(const CategoriesState()) {
    on<CategoriesSubscriptionRequested>(_onSubscriptionRequested);
    on<CategoriesListUpdated>(_onListUpdated);
    on<CategoriesRefreshRequested>(_onRefreshRequested);
    on<CategoryCreateRequested>(_onCreateRequested);
    on<CategoryDeleted>(_onDeleted);
  }

  final CategoryRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    CategoriesSubscriptionRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(state.copyWith(status: CategoriesStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(CategoriesListUpdated(await _repository.getCategories()));
    });
    emit(
      state.copyWith(
        status: CategoriesStatus.ready,
        categories: await _repository.getCategories(),
      ),
    );
  }

  void _onListUpdated(
    CategoriesListUpdated event,
    Emitter<CategoriesState> emit,
  ) {
    emit(
      state.copyWith(
        status: CategoriesStatus.ready,
        categories: event.categories,
      ),
    );
  }

  Future<void> _onRefreshRequested(
    CategoriesRefreshRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    await _repository.pull();
  }

  Future<void> _onCreateRequested(
    CategoryCreateRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    await _repository.createCategory(
      name: event.name,
      type: event.type,
      color: event.color,
      icon: event.icon,
    );
  }

  Future<void> _onDeleted(
    CategoryDeleted event,
    Emitter<CategoriesState> emit,
  ) async {
    await _repository.deleteCategory(event.category);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
