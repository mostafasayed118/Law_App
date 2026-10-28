part of 'notification_feed_screen.dart';

/// A notification-metadata row. An **unread** row is tappable (tap = mark
/// read through the gateway's §8-audited write RPC, D-F6) with a filled
/// icon as the shape-based unread marker and an explicit semantics label —
/// never color alone. A **read** row keeps the D-C2 non-interactive shape:
/// no InkWell, no chevron, no trailing action.
///
/// [labels] carries the screen's posture: local rows map the synthetic type/
/// summary through the demo labels, while configured rows render the server
/// type/summary verbatim (Task 26 — the demo summary is keyed by the local
/// corpus type, never by a shared wire type from the server).
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.labels,
    required this.onMarkRead,
  });

  final Notification notification;
  final DemoLabels labels;
  final void Function(String id) onMarkRead;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String date = formatMediumDate(l10n, notification.serverTimestamp);
    final Widget tile = AppTile(
      icon: notification.isRead
          ? Icons.notifications_none_outlined
          : Icons.notifications,
      title: labels.notificationType(notification.type),
      subtitles: <String>[
        labels.notificationSummary(notification.type, notification.summary),
        date,
      ],
      trailing: NotificationCategoryChip(category: notification.category),
      // D-F6: only the unread row carries the mark-read tap; the chevron
      // stays off (the D-MSG1 metadata-first opt-out — the ripple is the
      // affordance, not a navigation chevron).
      onTap: notification.isRead ? null : () => onMarkRead(notification.id),
      showChevron: false,
    );
    if (notification.isRead) {
      return tile;
    }
    return Semantics(label: l10n.notificationsFeedUnreadSemantics, child: tile);
  }
}
