part of 'saving_goals_bloc.dart';

enum SavingGoalsStatus { initial, loading, ready }

class SavingGoalsState extends Equatable {
  const SavingGoalsState({
    this.status = SavingGoalsStatus.initial,
    this.goals = const [],
  });

  final SavingGoalsStatus status;
  final List<SavingGoalModel> goals;

  SavingGoalsState copyWith({
    SavingGoalsStatus? status,
    List<SavingGoalModel>? goals,
  }) => SavingGoalsState(
    status: status ?? this.status,
    goals: goals ?? this.goals,
  );

  @override
  List<Object?> get props => [status, goals];
}
