import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/notification.dart';
import '../domain/notification_gateway.dart';
import '../domain/notification_prefs_store.dart';
import 'notification_category_chip.dart';
import 'notification_cubit.dart';
import 'notification_state.dart';

/// Org-scoped notification-feed surface (`/notifications/feed`;
/// notification-feed slice, D-N1).
///
/// Renders the caller's **redacted metadata** rows newest-first (the dev
/// fake in env-less runs, the env-gated `SupabaseNotificationGateway` with
/// `notifications_select_org` server-side — any active org member reads the
/// org feed, matrix §4 member SHIP). Rows carry category / type / synthetic
/// summary / server timestamp / read flag (D-N3) and nothing else: no user
/// identity, no content.
///
/// **D-N6 write slice (D-F6, 2026-09-02):** an unread row is deliberately
/// tappable — tapping marks it read through the gateway's §8-audited write
/// RPC and the feed reloads. The D-C2/D-N2 "no row tap" pin is re-scoped
/// exactly the way 12.1 re-scoped D-MSG3: **read rows stay non-interactive
/// and chevron-free**; the unread marker is shape+affordance (filled icon +
/// ripple, never color alone) with a semantics label; there is **no
/// mark-all affordance** (a future additive slice).
class NotificationFeedScreen extends StatelessWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).notificationsFeedTitle),
      ),
      body: BlocProvider<NotificationCubit>(
        create: (BuildContext context) => NotificationCubit(
          serviceLocator<NotificationGateway>(),
          serviceLocator<NotificationPrefsStore>(),
        ),
        child: const _FeedSurface(),
      ),
    );
  }
}

class _FeedSurface extends StatefulWidget {
  const _FeedSurface();

  @override
  State<_FeedSurface> createState() => _FeedSurfaceState();
}

class _FeedSurfaceState extends State<_FeedSurface> {
  @override
  void initState() {
    super.initState();
    // The cubit's initial state is already loading, so the first frame
    // settles straight into the fake's immediate list (the billing/vault
    // pattern).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<NotificationCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (BuildContext context, NotificationState state) {
          // D-N5/D-PF3: the honest muted note when rows existed but every
          // category toggle hid them — never the plain "No notifications"
          // copy, which would be false.
          final Widget empty = Padding(
            padding: const EdgeInsetsDirectional.only(
              top: LegalHubTheme.spaceMd,
            ),
            child: Text(
              state.allMuted
                  ? l10n.notificationsFeedMutedEmpty
                  : l10n.notificationsFeedEmpty,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
          return ViewStateSwitch<List<Notification>>(
            state: state.notifications,
            onRetry: () => context.read<NotificationCubit>().load(),
            builder: (BuildContext context, List<Notification> notifications) =>
                ListView(
                  padding: const EdgeInsetsDirectional.all(
                    LegalHubTheme.marginMobile,
                  ),
                  children: <Widget>[
                    for (final Notification notification
                        in notifications) ...<Widget>[
                      _NotificationTile(
                        notification: notification,
                        onMarkRead: (String id) =>
                            context.read<NotificationCubit>().markRead(id),
                      ),
                      const SizedBox(height: LegalHubTheme.spaceSm),
                    ],
                    const SizedBox(height: LegalHubTheme.spaceLg),
                    Text(
                      l10n.notificationsFeedLocalOnlyNote,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            empty: empty,
            errorCopy: l10n.notificationsFeedError,
          );
        },
      ),
    );
  }
}

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
