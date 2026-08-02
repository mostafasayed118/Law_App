import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/notification_prefs.dart';
import '../domain/notification_prefs_store.dart';
import 'notification_prefs_cubit.dart';

/// User-level notification preferences (foundation scope).
///
/// Local-only UX preferences: three toggles persisted on this device via the
/// [NotificationPrefsStore] seam, mirroring how the locale is persisted.
/// Delivery of notifications is a v1 capability and is explicitly labeled as
/// such on the screen (§1.3 no-false-assurance) — nothing here is sent to a
/// server.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (BuildContext context) =>
          NotificationPrefsCubit(serviceLocator<NotificationPrefsStore>())
            ..load(),
      child: const _NotificationSettingsBody(),
    );
  }
}

class _NotificationSettingsBody extends StatelessWidget {
  const _NotificationSettingsBody();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationPrefs prefs = context
        .watch<NotificationPrefsCubit>()
        .state
        .prefs;
    final NotificationPrefsCubit cubit = context.read<NotificationPrefsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          Text(
            l10n.notificationsNote,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifAppointmentReminders),
            value: prefs.appointmentReminders,
            onChanged: cubit.setAppointmentReminders,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifActivityUpdates),
            value: prefs.activityUpdates,
            onChanged: cubit.setActivityUpdates,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.notifSystemAlerts),
            value: prefs.systemAlerts,
            onChanged: cubit.setSystemAlerts,
          ),
        ],
      ),
    );
  }
}
