part of 'saving_goals_bloc.dart';

sealed class SavingGoalsEvent extends Equatable {
  const SavingGoalsEvent();

  @override
  List<Object?> get props => [];
}

class SavingGoalsSubscriptionRequested extends SavingGoalsEvent {
  const SavingGoalsSubscriptionRequested();
}

class SavingGoalsListUpdated extends SavingGoalsEvent {
  const SavingGoalsListUpdated(this.goals);

  final List<SavingGoalModel> goals;

  @override
  List<Object?> get props => [goals];
}

class SavingGoalsRefreshRequested extends SavingGoalsEvent {
  const SavingGoalsRefreshRequested();
}

class SavingGoalCreateRequested extends SavingGoalsEvent {
  const SavingGoalCreateRequested({
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.color,
  });

  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String? color;

  @override
  List<Object?> get props => [
    name,
    targetAmount,
    currentAmount,
    targetDate,
    color,
  ];
}

class SavingGoalUpdateRequested extends SavingGoalsEvent {
  const SavingGoalUpdateRequested(this.goal);

  final SavingGoalModel goal;

  @override
  List<Object?> get props => [goal];
}

class SavingGoalDeleted extends SavingGoalsEvent {
  const SavingGoalDeleted(this.goal);

  final SavingGoalModel goal;

  @override
  List<Object?> get props => [goal];
}
