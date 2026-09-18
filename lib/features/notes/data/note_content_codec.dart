import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

/// Converts between a note's stored `content`/`contentFormat` columns and a
/// Quill [Document] — the single place that knows both representations, so
/// the editor, the card preview and the public viewer all agree on them.
///
/// `content_format` legacy values are `'plain'` (a bare string, from before
/// the rich editor existed) and `'delta'` (a JSON-encoded Quill Delta ops
/// array, `jsonEncode(document.toDelta().toJson())`). Every note saved by
/// the app from now on is written back as `'delta'` — see
/// `NoteEditorPage._save` — so `'plain'` only ever appears on notes that
/// haven't been opened in the editor since this format landed.
class NoteContentCodec {
  const NoteContentCodec._();

  static Document decode(String? content, String contentFormat) {
    if (content == null || content.isEmpty) {
      return Document();
    }
    if (contentFormat != 'delta') {
      return Document.fromDelta(Delta()..insert('$content\n'));
    }
    try {
      return Document.fromJson(jsonDecode(content) as List<dynamic>);
    } on FormatException {
      // Corrupt/unexpected payload — degrade to plain text rather than
      // crashing the editor.
      return Document.fromDelta(Delta()..insert('$content\n'));
    }
  }

  static String encode(Document document) =>
      jsonEncode(document.toDelta().toJson());

  /// Single-line plain-text excerpt for list previews (`NoteCard`).
  static String plainTextExcerpt(String? content, String contentFormat) {
    if (content == null || content.isEmpty) {
      return '';
    }
    if (contentFormat != 'delta') {
      return content;
    }

    return decode(content, contentFormat).toPlainText().trim();
  }
}
