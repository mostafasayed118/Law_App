import 'package:equatable/equatable.dart';

/// Category of a notification-feed row (notification-feed slice, D-N4).
///
/// Exactly the three generic categories the device-local prefs already use
/// (`appointment` / `activity` / `system` — the D-N4 honest bridge: prefs
/// record what the user wants; the feed is where categories would
/// eventually be honored). The `notifications.category` CHECK admits only
/// these three strings; a provider row outside the set fails mapping loudly
/// (the gateway's malformed-row guard), never surfaces as a silently wrong
/// category.
enum NotificationCategory { appointment, activity, system }

/// One redacted notification-feed **metadata** row (notification-feed slice,
/// D-N3).
///
/// Carries **non-PII metadata only**: a stable id, a category, a type, a
/// synthetic summary, a server timestamp, and the server-tracked read flag.
/// **There is no user identity, no message content, and no raw text beyond
/// the synthetic summary** — the redaction posture is structural (T1 Q1:
/// the applied `notifications` table has no user-identity/content column, so
/// PII *cannot* be stored, not merely shouldn't). Rows are org-scoped
/// (D-N2/D-N3) and **read-only in v1**: `isRead` is display metadata only
/// (D-N6 — no read-flag RPC; the feed never mutates).
class Notification extends Equatable {
  const Notification({
    required this.id,
    required this.category,
    required this.type,
    required this.summary,
    required this.serverTimestamp,
    required this.isRead,
  });

  final String id;

  final NotificationCategory category;

  /// The row's type from the D-N3 example set (`matter_updated`,
  /// `message_received`, `invoice_status`, `appointment_reminder`, …) —
  /// rendered as-is, never localized (the fake mirrors the seeded types so
  /// the env-less and configured surfaces stay consistent).
  final String type;

  /// Synthetic demo copy only, never PII by convention (D-N3/D-N7).
  final String summary;

  final DateTime serverTimestamp;

  /// Server-tracked read flag — **display metadata only in v1** (D-N6: the
  /// feed renders rows without mutating; the read-flag RPC is a future
  /// write slice).
  final bool isRead;

  @override
  List<Object?> get props => <Object?>[
    id,
    category,
    type,
    summary,
    serverTimestamp,
    isRead,
  ];
}
