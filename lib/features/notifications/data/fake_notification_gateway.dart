import '../../../core/errors/result.dart';
import '../domain/notification.dart';
import '../domain/notification_gateway.dart';

/// Development-only notification-feed implementation: a fixed synthetic list
/// of non-PII notification **metadata**.
///
/// D-N7 — synthetic demo rows first: [fetchNotifications] returns the same
/// deterministic list on every call, with generic synthetic copy that never
/// reads as a real client's notification (the audit-row discipline, D-N3).
/// Rows carry id / category / type / synthetic summary / server timestamp /
/// read flag only — **no user identity, no content, no raw text** (the
/// redaction posture made structural in the applied table, T1 Q1). The
/// types mirror the fixture-seeded D-N3 example set exactly
/// (`appointment_reminder` / `matter_updated` / `invoice_status` /
/// `system_maintenance` / `message_received`) so the env-less fake and the
/// configured Supabase surface render the same shape. **No delivery, no
/// push** (D-N2). The read-flag mark (D-N6 slice, D-F5) mirrors the server
/// contract per instance: marks flip that instance's view of the rows
/// deterministically (the static corpus itself stays immutable so tests
/// stay isolated); re-marking read rows is idempotent (D-F4). The list
/// resolves immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
class FakeNotificationGateway implements NotificationGateway {
  /// The fixed synthetic notification-metadata list served by
  /// [fetchNotifications], newest-first.
  static final List<Notification> syntheticNotifications = <Notification>[
    Notification(
      id: 'notification-1',
      category: NotificationCategory.system,
      type: 'invoice_status',
      summary: 'Demo notification — invoice issued',
      serverTimestamp: DateTime.utc(2026, 7, 20, 9, 30),
      isRead: false,
    ),
    Notification(
      id: 'notification-2',
      category: NotificationCategory.activity,
      type: 'matter_updated',
      summary: 'Demo notification — matter status update',
      serverTimestamp: DateTime.utc(2026, 7, 18, 14, 5),
      isRead: false,
    ),
    Notification(
      id: 'notification-3',
      category: NotificationCategory.appointment,
      type: 'appointment_reminder',
      summary: 'Demo notification — consultation reminder',
      serverTimestamp: DateTime.utc(2026, 7, 15, 8, 0),
      isRead: true,
    ),
    Notification(
      id: 'notification-4',
      category: NotificationCategory.activity,
      type: 'message_received',
      summary: 'Demo notification — new message in thread',
      serverTimestamp: DateTime.utc(2026, 7, 12, 16, 45),
      isRead: true,
    ),
    Notification(
      id: 'notification-5',
      category: NotificationCategory.system,
      type: 'system_maintenance',
      summary: 'Demo notification — scheduled maintenance',
      serverTimestamp: DateTime.utc(2026, 7, 10, 2, 0),
      isRead: false,
    ),
  ];

  /// This instance's mark state (D-F5 mirror): ids marked read through
  /// [markNotificationsRead]. Instance-level so the shared static corpus
  /// stays immutable across tests; unknown ids are silently ignored (the
  /// D-F1 count-honest posture).
  final Set<String> _marked = <String>{};

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    // Metadata only — the synthetic list is returned with this instance's
    // mark state projected onto the read flags; nothing crosses this
    // boundary but the D-N3 metadata surface (no delivery capability).
    final List<Notification> rows = syntheticNotifications
        .map(
          (Notification n) => _marked.contains(n.id)
              ? Notification(
                  id: n.id,
                  category: n.category,
                  type: n.type,
                  summary: n.summary,
                  serverTimestamp: n.serverTimestamp,
                  isRead: true,
                )
              : n,
        )
        .toList(growable: false);
    return Result<List<Notification>>.success(
      List<Notification>.unmodifiable(rows),
    );
  }

  @override
  Future<Result<int>> markNotificationsRead(List<String> ids) async {
    // D-F4 idempotent count: only the still-unread known ids flip; unknown
    // ids are silently ignored (the D-F1 count-honest posture).
    final Map<String, Notification> byId = <String, Notification>{
      for (final Notification n in syntheticNotifications) n.id: n,
    };
    final int flipped = ids
        .where(
          (String id) =>
              byId.containsKey(id) &&
              !byId[id]!.isRead &&
              !_marked.contains(id),
        )
        .length;
    _marked.addAll(ids);
    return Result<int>.success(flipped);
  }
}
