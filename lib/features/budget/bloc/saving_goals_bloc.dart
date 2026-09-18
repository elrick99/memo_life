import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/saving_goal_model.dart';
import '../data/saving_goal_repository.dart';

part 'saving_goals_event.dart';
part 'saving_goals_state.dart';

class SavingGoalsBloc extends Bloc<SavingGoalsEvent, SavingGoalsState> {
  SavingGoalsBloc({required this._repository})
    : super(const SavingGoalsState()) {
    on<SavingGoalsSubscriptionRequested>(_onSubscriptionRequested);
    on<SavingGoalsListUpdated>(_onListUpdated);
    on<SavingGoalsRefreshRequested>(_onRefreshRequested);
    on<SavingGoalCreateRequested>(_onCreateRequested);
    on<SavingGoalUpdateRequested>(_onUpdateRequested);
    on<SavingGoalDeleted>(_onDeleted);
  }

  final SavingGoalRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    SavingGoalsSubscriptionRequested event,
    Emitter<SavingGoalsState> emit,
  ) async {
    emit(state.copyWith(status: SavingGoalsStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(SavingGoalsListUpdated(await _repository.getSavingGoals()));
    });
    emit(
      state.copyWith(
        status: SavingGoalsStatus.ready,
        goals: await _repository.getSavingGoals(),
      ),
    );
  }

  void _onListUpdated(
    SavingGoalsListUpdated event,
    Emitter<SavingGoalsState> emit,
  ) {
    emit(state.copyWith(status: SavingGoalsStatus.ready, goals: event.goals));
  }

  Future<void> _onRefreshRequested(
    SavingGoalsRefreshRequested event,
    Emitter<SavingGoalsState> emit,
  ) async {
    await _repository.pull();
  }

  Future<void> _onCreateRequested(
    SavingGoalCreateRequested event,
    Emitter<SavingGoalsState> emit,
  ) async {
    await _repository.createSavingGoal(
      name: event.name,
      targetAmount: event.targetAmount,
      currentAmount: event.currentAmount,
      targetDate: event.targetDate,
      color: event.color,
    );
  }

  Future<void> _onUpdateRequested(
    SavingGoalUpdateRequested event,
    Emitter<SavingGoalsState> emit,
  ) async {
    await _repository.updateSavingGoal(event.goal);
  }

  Future<void> _onDeleted(
    SavingGoalDeleted event,
    Emitter<SavingGoalsState> emit,
  ) async {
    await _repository.deleteSavingGoal(event.goal);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
