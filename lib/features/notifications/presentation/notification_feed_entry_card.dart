import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the org-scoped notification feed
/// (`/notifications/feed`; notification-feed slice, D-N1).
///
/// Rendered on the home screen when the session's role grants
/// [RoleCapability.canViewNotifications] — **every authenticated role**
/// (matrix §4 "View notifications (metadata)" member SHIP — the
/// organizations gate admits any active member of the org, no role
/// hierarchy in the feed, T1 Q3). Like every capability flag in this
/// product, it is a navigation hint only — never an authorization grant;
/// the RLS gate is server-side and `platform_owner_admin` is denied
/// always (D-P0C1(a)).
class NotificationFeedEntryCard extends StatelessWidget {
  const NotificationFeedEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.notifications_none_outlined,
      title: l10n.notificationsFeedEntryTitle,
      subtitle: l10n.notificationsFeedEntrySubtitle,
      onTap: onTap,
    );
  }
}
