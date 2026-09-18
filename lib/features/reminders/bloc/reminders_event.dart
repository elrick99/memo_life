part of 'reminders_bloc.dart';

sealed class RemindersEvent extends Equatable {
  const RemindersEvent();

  @override
  List<Object?> get props => [];
}

class RemindersSubscriptionRequested extends RemindersEvent {
  const RemindersSubscriptionRequested();
}

class RemindersListUpdated extends RemindersEvent {
  const RemindersListUpdated(this.reminders);

  final List<ReminderModel> reminders;

  @override
  List<Object?> get props => [reminders];
}

class RemindersRefreshRequested extends RemindersEvent {
  const RemindersRefreshRequested();
}

class RemindersCompletedFilterToggled extends RemindersEvent {
  const RemindersCompletedFilterToggled();
}

class ReminderCreateRequested extends RemindersEvent {
  const ReminderCreateRequested({
    this.noteLocalUuid,
    this.categoryLocalUuid,
    required this.title,
    this.description,
    required this.dueAt,
    this.type = 'task',
    this.priority = 'normal',
    this.recurrence = 'none',
  });

  final String? noteLocalUuid;
  final String? categoryLocalUuid;
  final String title;
  final String? description;
  final DateTime dueAt;
  final String type;
  final String priority;
  final String recurrence;

  @override
  List<Object?> get props => [
    noteLocalUuid,
    categoryLocalUuid,
    title,
    description,
    dueAt,
    type,
    priority,
    recurrence,
  ];
}

class ReminderUpdateRequested extends RemindersEvent {
  const ReminderUpdateRequested(this.reminder);

  final ReminderModel reminder;

  @override
  List<Object?> get props => [reminder];
}

class ReminderCompletedToggled extends RemindersEvent {
  const ReminderCompletedToggled(this.reminder);

  final ReminderModel reminder;

  @override
  List<Object?> get props => [reminder];
}

class ReminderDeleted extends RemindersEvent {
  const ReminderDeleted(this.reminder);

  final ReminderModel reminder;

  @override
  List<Object?> get props => [reminder];
}
