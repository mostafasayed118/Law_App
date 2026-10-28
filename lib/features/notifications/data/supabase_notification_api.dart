/// Provider-neutral notifications-table seam.
///
/// The seam is the only surface the notification gateway talks to: plain map
/// rows out, typed [SupabaseNotificationException]s on failure. Provider
/// types never cross this boundary (same discipline as [SupabaseBillingApi]
/// / [SupabaseStorageApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `BillingTableCaller` from the
/// billing seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef NotificationTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// A PostgREST RPC call: function name + params → the raw scalar result
/// (the read-flag write slice, D-F5 — `mark_notifications_read` returns the
/// flipped-row count). Plain function type so tests inject a closure.
typedef NotificationRpcCaller =
    Future<Object?> Function(String fn, Map<String, dynamic>? params);

/// Typed reasons the notifications read can fail, mapped from the PostgREST
/// surface. The read path is a plain RLS-scoped SELECT — the RPC-specific
/// kinds of the organization seam cannot occur here.
enum SupabaseNotificationFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseNotificationApi] seam.
class SupabaseNotificationException implements Exception {
  const SupabaseNotificationException({
    required this.kind,
    required this.message,
  });

  final SupabaseNotificationFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseNotificationException(${kind.name}): $message';
}

/// notifications-table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (T1 Q2): the `notifications_select_org` policy
/// returns only the rows whose org the caller is an **active member of** —
/// the organizations gate (org-wide metadata, NOT the matter-assignment
/// exists-subquery; any active member reads the org feed, matrix §4 member
/// SHIP; `platform_owner_admin` deny-always, non-member/cross-org/anon
/// denied). Rows carry ids + the D-N3 metadata columns only; the table is
/// **redaction-structural by construction** (T1 Q1 — no user-identity or
/// content column exists), so no PII can cross this seam.
abstract interface class SupabaseNotificationApi {
  /// The caller's org-scoped `notifications` rows.
  ///
  /// Columns requested: `id`, `category`, `type`, `summary`,
  /// `server_timestamp`, `is_read` — the metadata-only read surface the
  /// [Notification] VO needs (D-N3). Newest-first ordering is the gateway's
  /// presentation contract (no server-side order in the data layer, the
  /// billing/documents precedent); the `notifications_org_ts` composite
  /// index serves the org gate scan.
  Future<List<Map<String, dynamic>>> fetchNotifications();

  /// Marks the given notification ids read for the caller (D-N6 write
  /// slice, D-F1): the server-side `mark_notifications_read` RPC flips only
  /// the caller's own-org, still-unread rows (the in-function
  /// `is_active_member` gate — foreign-org ids are silently untouched) and
  /// returns the flipped-row count. §8-audited server-side (D-F2).
  Future<int> markNotificationsRead(List<String> ids);
}
