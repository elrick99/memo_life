part of 'reminders_bloc.dart';

enum RemindersStatus { initial, loading, ready }

class RemindersState extends Equatable {
  const RemindersState({
    this.status = RemindersStatus.initial,
    this.reminders = const [],
    this.showCompleted = false,
  });

  final RemindersStatus status;
  final List<ReminderModel> reminders;
  final bool showCompleted;

  List<ReminderModel> get visibleReminders => reminders
      .where((reminder) => reminder.isCompleted == showCompleted)
      .toList();

  RemindersState copyWith({
    RemindersStatus? status,
    List<ReminderModel>? reminders,
    bool? showCompleted,
  }) => RemindersState(
    status: status ?? this.status,
    reminders: reminders ?? this.reminders,
    showCompleted: showCompleted ?? this.showCompleted,
  );

  @override
  List<Object?> get props => [status, reminders, showCompleted];
}
