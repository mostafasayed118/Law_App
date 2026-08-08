import 'package:equatable/equatable.dart';

/// A single message row in a thread (sixth §14 un-deferral, realtime slice
/// D-RT5).
///
/// Carries the real read-path surface: a stable id, the author's **stored
/// display name** (D-RT4 — never an identity claim; the demo seed carries
/// generic demo names only), the message body, and the sent timestamp. The
/// `body` field is the **D-MSG1 consummation** — the first content column in
/// the public schema, scoped to the read path (no write grant, no
/// send/reply/composer in this slice). There is deliberately **no
/// attachment, no read-receipt, no edit history, and no author user-id
/// field** anywhere on the type (D-RT3/D-RT4) — the read-only line is
/// enforced structurally. Messages come from the fake gateway's
/// deterministic per-thread synthetic rows in env-less runs, and bodies are
/// generic demo copy (R1: fake-data honesty — nothing here may read as a
/// real case communication).
class Message extends Equatable {
  const Message({
    required this.id,
    required this.authorDisplayName,
    required this.body,
    required this.sentAt,
  });

  final String id;

  /// The author's stored display name — generic demo names only in the
  /// seed/fake (D-RT4); never a real account identity.
  final String authorDisplayName;

  /// The message body — generic demo content in the seed/fake, never real
  /// client or legal data (R1/D-RT4).
  final String body;

  final DateTime sentAt;

  @override
  List<Object?> get props => <Object?>[id, authorDisplayName, body, sentAt];
}
