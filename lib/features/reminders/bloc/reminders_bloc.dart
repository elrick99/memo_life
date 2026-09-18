import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/reminder_model.dart';
import '../data/reminder_repository.dart';

part 'reminders_event.dart';
part 'reminders_state.dart';

class RemindersBloc extends Bloc<RemindersEvent, RemindersState> {
  RemindersBloc({required this._repository}) : super(const RemindersState()) {
    on<RemindersSubscriptionRequested>(_onSubscriptionRequested);
    on<RemindersListUpdated>(_onListUpdated);
    on<RemindersRefreshRequested>(_onRefreshRequested);
    on<RemindersCompletedFilterToggled>(_onCompletedFilterToggled);
    on<ReminderCreateRequested>(_onCreateRequested);
    on<ReminderUpdateRequested>(_onUpdateRequested);
    on<ReminderCompletedToggled>(_onCompletedToggled);
    on<ReminderDeleted>(_onDeleted);
  }

  final ReminderRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    RemindersSubscriptionRequested event,
    Emitter<RemindersState> emit,
  ) async {
    emit(state.copyWith(status: RemindersStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(RemindersListUpdated(await _repository.getReminders()));
    });
    emit(
      state.copyWith(
        status: RemindersStatus.ready,
        reminders: await _repository.getReminders(),
      ),
    );
  }

  void _onListUpdated(
    RemindersListUpdated event,
    Emitter<RemindersState> emit,
  ) {
    emit(
      state.copyWith(status: RemindersStatus.ready, reminders: event.reminders),
    );
  }

  Future<void> _onRefreshRequested(
    RemindersRefreshRequested event,
    Emitter<RemindersState> emit,
  ) async {
    await _repository.pull();
  }

  void _onCompletedFilterToggled(
    RemindersCompletedFilterToggled event,
    Emitter<RemindersState> emit,
  ) {
    emit(state.copyWith(showCompleted: !state.showCompleted));
  }

  Future<void> _onCreateRequested(
    ReminderCreateRequested event,
    Emitter<RemindersState> emit,
  ) async {
    await _repository.createReminder(
      noteLocalUuid: event.noteLocalUuid,
      categoryLocalUuid: event.categoryLocalUuid,
      title: event.title,
      description: event.description,
      dueAt: event.dueAt,
      type: event.type,
      priority: event.priority,
      recurrence: event.recurrence,
    );
  }

  Future<void> _onUpdateRequested(
    ReminderUpdateRequested event,
    Emitter<RemindersState> emit,
  ) async {
    await _repository.updateReminder(event.reminder);
  }

  Future<void> _onCompletedToggled(
    ReminderCompletedToggled event,
    Emitter<RemindersState> emit,
  ) async {
    await _repository.toggleCompleted(event.reminder);
  }

  Future<void> _onDeleted(
    ReminderDeleted event,
    Emitter<RemindersState> emit,
  ) async {
    await _repository.deleteReminder(event.reminder);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
