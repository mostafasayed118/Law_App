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

part 'notification_feed_tile.dart';

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
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsFeedTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10). The
      // empty copy is a state builder here because it depends on the state:
      // D-N5/D-PF3 render the honest muted note when rows existed but every
      // category toggle hid them, never the plain "No notifications" copy.
      body:
          CubitListSurface<NotificationCubit, NotificationState, Notification>(
            createCubit: () => NotificationCubit(
              serviceLocator<NotificationGateway>(),
              serviceLocator<NotificationPrefsStore>(),
            ),
            project: (NotificationState state) => state.notifications,
            load: (NotificationCubit cubit) => cubit.load(),
            tileBuilder: (BuildContext context, Notification notification) =>
                _NotificationTile(
                  notification: notification,
                  onMarkRead: (String id) =>
                      context.read<NotificationCubit>().markRead(id),
                ),
            empty: (BuildContext context, NotificationState state) => Padding(
              padding: const EdgeInsetsDirectional.only(
                top: LegalHubTheme.spaceMd,
              ),
              child: Text(
                state.allMuted
                    ? l10n.notificationsFeedMutedEmpty
                    : l10n.notificationsFeedEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            errorCopy: l10n.notificationsFeedError,
            localOnlyNote: l10n.notificationsFeedLocalOnlyNote,
          ),
    );
  }
}
