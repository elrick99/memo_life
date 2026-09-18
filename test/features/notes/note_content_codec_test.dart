import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_life/features/notes/data/note_content_codec.dart';

void main() {
  group('decode', () {
    test('an empty/null content decodes to an empty document', () {
      expect(NoteContentCodec.decode(null, 'plain').isEmpty(), isTrue);
      expect(NoteContentCodec.decode('', 'delta').isEmpty(), isTrue);
    });

    test('plain content becomes a single-line delta document', () {
      final document = NoteContentCodec.decode('Bonjour', 'plain');

      expect(document.toPlainText(), 'Bonjour\n');
    });

    test('delta content round-trips through encode/decode', () {
      final content = jsonEncode([
        {'insert': 'Bonjour '},
        {
          'insert': 'le monde',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);

      final document = NoteContentCodec.decode(content, 'delta');

      expect(document.toPlainText(), 'Bonjour le monde\n');
    });

    test(
      'a corrupt delta payload degrades to plain text instead of crashing',
      () {
        final document = NoteContentCodec.decode(
          'not json at all {{{',
          'delta',
        );

        expect(document.toPlainText(), 'not json at all {{{\n');
      },
    );
  });

  group('encode', () {
    test('encodes a document back to a decodable delta JSON string', () {
      final original = NoteContentCodec.decode('Salut', 'plain');
      final encoded = NoteContentCodec.encode(original);
      final decoded = NoteContentCodec.decode(encoded, 'delta');

      expect(decoded.toPlainText(), 'Salut\n');
    });
  });

  group('plainTextExcerpt', () {
    test('returns plain content unchanged', () {
      expect(
        NoteContentCodec.plainTextExcerpt('Texte brut', 'plain'),
        'Texte brut',
      );
    });

    test('extracts trimmed plain text from a delta payload', () {
      final content = jsonEncode([
        {'insert': 'Une note\n'},
      ]);

      expect(NoteContentCodec.plainTextExcerpt(content, 'delta'), 'Une note');
    });

    test('returns an empty string for null/empty content', () {
      expect(NoteContentCodec.plainTextExcerpt(null, 'delta'), '');
      expect(NoteContentCodec.plainTextExcerpt('', 'plain'), '');
    });
  });
}
