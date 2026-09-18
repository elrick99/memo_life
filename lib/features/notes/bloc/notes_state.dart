part of 'notes_bloc.dart';

enum NotesStatus { initial, loading, ready }

class NotesState extends Equatable {
  const NotesState({
    this.status = NotesStatus.initial,
    this.notes = const [],
    this.showArchived = false,
  });

  final NotesStatus status;
  final List<NoteModel> notes;
  final bool showArchived;

  List<NoteModel> get visibleNotes =>
      notes.where((note) => note.isArchived == showArchived).toList();

  NotesState copyWith({
    NotesStatus? status,
    List<NoteModel>? notes,
    bool? showArchived,
  }) => NotesState(
    status: status ?? this.status,
    notes: notes ?? this.notes,
    showArchived: showArchived ?? this.showArchived,
  );

  @override
  List<Object?> get props => [status, notes, showArchived];
}
