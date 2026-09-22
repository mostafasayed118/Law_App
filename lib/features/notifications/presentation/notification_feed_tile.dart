part of 'notification_feed_screen.dart';

/// A notification-metadata row. An **unread** row is tappable (tap = mark
/// read through the gateway's §8-audited write RPC, D-F6) with a filled
/// icon as the shape-based unread marker and an explicit semantics label —
/// never color alone. A **read** row keeps the D-C2 non-interactive shape:
/// no InkWell, no chevron, no trailing action.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onMarkRead,
  });

  final Notification notification;
  final void Function(String id) onMarkRead;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String date = formatMediumDate(l10n, notification.serverTimestamp);
    final Widget tile = AppTile(
      icon: notification.isRead
          ? Icons.notifications_none_outlined
          : Icons.notifications,
      title: notification.type,
      subtitles: <String>[notification.summary, date],
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
