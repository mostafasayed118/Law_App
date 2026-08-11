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
/// push, no read-flag mutation** (D-N2/D-N6). The list resolves immediately
/// (no artificial delay) so cubit/widget tests stay timing-independent.
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

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    // Metadata only — the synthetic list is returned as-is; nothing crosses
    // this boundary but the D-N3 metadata surface (no delivery capability).
    return Result<List<Notification>>.success(syntheticNotifications);
  }
}
