import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/notification.dart';
import '../domain/notification_gateway.dart';
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
/// identity, no content, **no row tap and no trailing action** (D-C2 —
/// read-only metadata rows must not read as tappable; D-N2: no push, no
/// delivery, no read-flag write).
class NotificationFeedScreen extends StatelessWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).notificationsFeedTitle),
      ),
      body: BlocProvider<NotificationCubit>(
        create: (BuildContext context) =>
            NotificationCubit(serviceLocator<NotificationGateway>()),
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
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.notificationsFeedEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return SafeArea(
      child: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (BuildContext context, NotificationState state) {
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
                      _NotificationTile(notification: notification),
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

/// A read-only notification-metadata row. Carries **no onTap, no TapTarget,
/// and no trailing action** — the D-N2/D-N3 read-only line: rows must not
/// read as tappable and no delivery/read-flag affordance exists.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final Notification notification;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String date = formatMediumDate(l10n, notification.serverTimestamp);
    return AppTile(
      icon: Icons.notifications_none_outlined,
      title: notification.type,
      subtitles: <String>[notification.summary, date],
      trailing: NotificationCategoryChip(category: notification.category),
    );
  }
}
