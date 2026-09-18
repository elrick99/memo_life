part of 'notes_bloc.dart';

sealed class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching the local cache (subscribes to [NoteRepository.changes])
/// and loads the current list. Dispatched once when the notes tab mounts.
class NotesSubscriptionRequested extends NotesEvent {
  const NotesSubscriptionRequested();
}

class NotesListUpdated extends NotesEvent {
  const NotesListUpdated(this.notes);

  final List<NoteModel> notes;

  @override
  List<Object?> get props => [notes];
}

/// Pull-to-refresh: forces an immediate sync attempt on top of the
/// semi-automatic (connectivity-triggered) one.
class NotesRefreshRequested extends NotesEvent {
  const NotesRefreshRequested();
}

class NotesArchivedFilterToggled extends NotesEvent {
  const NotesArchivedFilterToggled();
}

class NoteCreateRequested extends NotesEvent {
  const NoteCreateRequested({
    this.categoryLocalUuid,
    this.tagLocalUuids = const [],
    required this.title,
    this.content,
    this.contentFormat = 'plain',
    this.checklist = const [],
    this.priority = 'normal',
  });

  final String? categoryLocalUuid;
  final List<String> tagLocalUuids;
  final String title;
  final String? content;
  final String contentFormat;
  final List<ChecklistItem> checklist;
  final String priority;

  @override
  List<Object?> get props => [
    categoryLocalUuid,
    tagLocalUuids,
    title,
    content,
    contentFormat,
    checklist,
    priority,
  ];
}

class NoteUpdateRequested extends NotesEvent {
  const NoteUpdateRequested(this.note);

  final NoteModel note;

  @override
  List<Object?> get props => [note];
}

class NoteDeleted extends NotesEvent {
  const NoteDeleted(this.note);

  final NoteModel note;

  @override
  List<Object?> get props => [note];
}

class NoteArchiveToggled extends NotesEvent {
  const NoteArchiveToggled(this.note);

  final NoteModel note;

  @override
  List<Object?> get props => [note];
}

class NotePinToggled extends NotesEvent {
  const NotePinToggled(this.note);

  final NoteModel note;

  @override
  List<Object?> get props => [note];
}

class NoteLockToggled extends NotesEvent {
  const NoteLockToggled(this.note);

  final NoteModel note;

  @override
  List<Object?> get props => [note];
}
