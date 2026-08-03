import 'package:equatable/equatable.dart';

/// A synthetic message-thread preview (Phase 9, owner decisions D-MSG1/D-MSG4).
///
/// Carries **non-PII thread metadata only**: a stable synthetic id, a generic
/// demo thread title, a matter reference (a synthetic matter title), the
/// participants (generic demo roster names), a last-activity date, and a
/// message count. **There is no message body, no last-message text, no
/// preview, no attachment, and no sender/message pair field anywhere on the
/// type** (D-MSG1) — the body-less line is enforced structurally, so the
/// messaging surface can never render message content and the
/// `permission_matrix.md` §4 "Read a document/message body" row is never
/// exercised. The real messages data path stays §13-deferred and this shape
/// is TBD; threads come only from the fake gateway's fixed synthetic list,
/// and titles are static demo copy (R1: fake-data honesty — nothing here may
/// read as a real case communication).
class MessageThread extends Equatable {
  const MessageThread({
    required this.id,
    required this.title,
    required this.matterRef,
    required this.participants,
    required this.lastActivityAt,
    required this.messageCount,
  });

  final String id;

  /// Generic demo wording — never a real case or communication reference
  /// (D-MSG4, R1).
  final String title;

  /// The matter this thread belongs to, rendered as one of the existing
  /// synthetic matter titles (D-MSG4 — no new identity surface).
  final String matterRef;

  /// Generic demo roster names only (Phase 6/7 synthetic names + the neutral
  /// "Demo client"); presentation-only, never an identity or availability
  /// claim. **Must not be mutated** — the fake serves the same instances on
  /// every call, and the determinism pin depends on the shared list staying
  /// untouched (no consumer may sort/append/remove participants).
  final List<String> participants;

  final DateTime lastActivityAt;

  /// Synthetic message count (> 0). A count, never message content.
  final int messageCount;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    matterRef,
    participants,
    lastActivityAt,
    messageCount,
  ];
}
