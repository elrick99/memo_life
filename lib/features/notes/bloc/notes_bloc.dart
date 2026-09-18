import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/checklist_item.dart';
import '../data/note_model.dart';
import '../data/note_repository.dart';

part 'notes_event.dart';
part 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc({required this._repository}) : super(const NotesState()) {
    on<NotesSubscriptionRequested>(_onSubscriptionRequested);
    on<NotesListUpdated>(_onListUpdated);
    on<NotesRefreshRequested>(_onRefreshRequested);
    on<NotesArchivedFilterToggled>(_onArchivedFilterToggled);
    on<NoteCreateRequested>(_onNoteCreateRequested);
    on<NoteUpdateRequested>(_onNoteUpdateRequested);
    on<NoteDeleted>(_onNoteDeleted);
    on<NoteArchiveToggled>(_onNoteArchiveToggled);
    on<NotePinToggled>(_onNotePinToggled);
    on<NoteLockToggled>(_onNoteLockToggled);
  }

  final NoteRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    NotesSubscriptionRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(state.copyWith(status: NotesStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(NotesListUpdated(await _repository.getNotes(includeArchived: true)));
    });
    emit(
      state.copyWith(
        status: NotesStatus.ready,
        notes: await _repository.getNotes(includeArchived: true),
      ),
    );
  }

  void _onListUpdated(NotesListUpdated event, Emitter<NotesState> emit) {
    emit(state.copyWith(status: NotesStatus.ready, notes: event.notes));
  }

  Future<void> _onRefreshRequested(
    NotesRefreshRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.pull();
  }

  void _onArchivedFilterToggled(
    NotesArchivedFilterToggled event,
    Emitter<NotesState> emit,
  ) {
    emit(state.copyWith(showArchived: !state.showArchived));
  }

  Future<void> _onNoteCreateRequested(
    NoteCreateRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.createNote(
      categoryLocalUuid: event.categoryLocalUuid,
      tagLocalUuids: event.tagLocalUuids,
      title: event.title,
      content: event.content,
      contentFormat: event.contentFormat,
      checklist: event.checklist,
      priority: event.priority,
    );
  }

  Future<void> _onNoteUpdateRequested(
    NoteUpdateRequested event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.updateNote(event.note);
  }

  Future<void> _onNoteDeleted(
    NoteDeleted event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.deleteNote(event.note);
  }

  Future<void> _onNoteArchiveToggled(
    NoteArchiveToggled event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.toggleArchive(event.note);
  }

  Future<void> _onNotePinToggled(
    NotePinToggled event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.togglePin(event.note);
  }

  Future<void> _onNoteLockToggled(
    NoteLockToggled event,
    Emitter<NotesState> emit,
  ) async {
    await _repository.toggleLock(event.note);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
