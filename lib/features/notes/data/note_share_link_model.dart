/// A note's public read-only link — server-authoritative, fetched fresh,
/// never cached/synced offline like [NoteModel] itself. Mirrors the payload
/// `NoteShareLinkController` returns (`show`'s metadata-only shape and
/// `store`'s one-time `url`).
class NoteShareLinkModel {
  const NoteShareLinkModel({required this.uuid, this.url, this.expiresAt});

  final String uuid;

  /// Only present right after creation (`store`) — the raw token is never
  /// persisted server-side, so a later `show` can't recover it.
  final String? url;
  final DateTime? expiresAt;

  factory NoteShareLinkModel.fromJson(Map<String, dynamic> json) =>
      NoteShareLinkModel(
        uuid: json['uuid'] as String,
        url: json['url'] as String?,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
      );
}
