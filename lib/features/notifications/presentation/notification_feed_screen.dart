import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/notifications/domain/notification.dart';
import 'package:legalhub/features/notifications/domain/notification_gateway.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs_store.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

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
    final bool localOnly = backendIsLocalOnly;
    final DemoLabels labels = DemoLabels(l10n, localOnly: localOnly);
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
                  labels: labels,
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
            localOnlyNote: localOnly ? l10n.notificationsFeedLocalOnlyNote : '',
            header: const <Widget>[_ActionErrorBanner()],
          ),
    );
  }
}

/// Inline banner for a failed mark-read action. It subscribes to the cubit
/// directly (the list shell's `buildWhen` only tracks the row projection, so
/// an action error that leaves the list untouched would not rebuild it).
class _ActionErrorBanner extends StatelessWidget {
  const _ActionErrorBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NotificationCubit, NotificationState, bool>(
      selector: (NotificationState state) => state.actionError != null,
      builder: (BuildContext context, bool hasError) {
        if (!hasError) {
          return const SizedBox.shrink();
        }
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: LegalHubTheme.spaceMd,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(LegalHubTheme.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceSm),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: LegalHubTheme.spaceSm),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).stateError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
