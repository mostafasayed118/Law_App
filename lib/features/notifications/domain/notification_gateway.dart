import '../../../core/errors/result.dart';
import 'notification.dart';

/// Notification-feed integration boundary (notification-feed slice, D-N1).
///
/// This slice **builds** the minimal org-scoped read surface (there was no
/// fake to swap): a dev fake is registered for env-less runs and ALL tests,
/// and the env-gated Supabase implementation takes over only in configured
/// builds behind `env.isConfigured` (the documents/messages/storage/billing
/// flip pattern). **Read metadata + the D-N6 write path** — no push, no
/// delivery, no provider decision ever crosses this boundary (D-N2; the
/// "no push" copy rule). The read-flag write (D-N6 slice, D-F5) is the
/// boundary's single mutation: mark-read, §8-audited server-side.
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class NotificationGateway {
  /// The caller's org-scoped notification-metadata list, newest-first
  /// (D-N3/D-N4). Server-side, `notifications_select_org` returns exactly
  /// the caller's active-org rows (the organizations gate — any active
  /// member; matrix §4 "View notifications (metadata)" member SHIP) and
  /// denies every other read (non-member / cross-org / anon /
  /// `platform_owner_admin` deny-always posture). Deterministic and
  /// read-only.
  Future<Result<List<Notification>>> fetchNotifications();

  /// Marks [ids] read for the caller (D-N6 write slice, D-F5): returns the
  /// flipped-row count. The server-side in-function gate flips only the
  /// caller's own-org, still-unread rows (foreign-org ids are silently
  /// untouched — never an error to the caller's own rows); a successful
  /// mark is §8-audited server-side (D-F2) and idempotent (D-F4).
  Future<Result<int>> markNotificationsRead(List<String> ids);
}
