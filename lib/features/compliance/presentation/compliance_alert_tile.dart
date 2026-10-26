part of 'compliance_alerts_screen.dart';

/// One alert row: severity icon + text label and status label, never color
/// alone (INSTRUCTIONS §4.5). Tapping opens the detail sheet.
class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.localOnly,
    required this.onTap,
  });

  final ComplianceAlert alert;
  final bool localOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DemoLabels labels = DemoLabels(l10n, localOnly: localOnly);
    return AppTile(
      title: labels.alertTitle(alert.title),
      subtitles: <String>[
        '${alertSeverityLabel(l10n, alert.severity)} · '
            '${alertStatusLabel(l10n, alert.status)}',
      ],
      leading: Icon(
        alertSeverityIcon(alert.severity),
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
