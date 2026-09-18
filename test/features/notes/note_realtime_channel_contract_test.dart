import 'package:flutter_test/flutter_test.dart';
import 'package:laravel_reverb/testing.dart';

/// Verifies the exact wire contract `NoteEditorPage` relies on against the
/// backend's `App\Events\NoteContentUpdated`: the presence channel name
/// (`presence-notes.{uuid}`, joined here as the bare `notes.{uuid}`) and the
/// custom `broadcastAs()` event name (`note.content-updated`, listened for
/// here as `.note.content-updated`). A mismatch on either string is exactly
/// the kind of bug that silently breaks realtime sync without failing any
/// backend test — the backend only proves the event dispatches, not that a
/// client can actually pick it up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a note.content-updated event on the presence-notes.{uuid} channel is delivered as the editor expects', () async {
    final fake = ReverbFake();
    await fake.connect();

    Map<String, dynamic>? received;
    fake.reverb
        .presence('notes.abc-123')
        .listen('.note.content-updated', (data) => received = data);
    await Future<void>.delayed(Duration.zero);

    fake.emit('presence-notes.abc-123', 'note.content-updated', {
      'note_uuid': 'abc-123',
      'title': 'Titre',
      'content': 'Nouveau contenu',
      'checklist': [
        {'text': 'Lait', 'completed': false},
      ],
      'updated_by': {'id': 2, 'name': 'Collègue'},
      'updated_at': '2026-09-17T12:00:00.000000Z',
    });
    await Future<void>.delayed(Duration.zero);

    expect(received, isNotNull);
    expect(received!['content'], 'Nouveau contenu');
    expect(received!['checklist'], hasLength(1));
    expect(received!['updated_at'], '2026-09-17T12:00:00.000000Z');
    fake.dispose();
  });
}
