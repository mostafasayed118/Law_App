part of 'notification_settings_screen.dart';

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
