import '../../../core/errors/result.dart';
import 'notification.dart';

/// Notification-feed integration boundary (notification-feed slice, D-N1).
///
/// This slice **builds** the minimal org-scoped read surface (there was no
/// fake to swap): a dev fake is registered for env-less runs and ALL tests,
/// and the env-gated Supabase implementation takes over only in configured
/// builds behind `env.isConfigured` (the documents/messages/storage/billing
/// flip pattern). **Read-only metadata** — no push, no delivery, no
/// read-flag write, no provider decision ever crosses this boundary
/// (D-N2/D-N6; the "no push" copy rule).
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
}
