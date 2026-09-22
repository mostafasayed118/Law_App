part of 'compliance_alerts_screen.dart';

/// A read-only alert row: text + severity label, never color alone
/// (INSTRUCTIONS §4.5); no tap affordance.
class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final ComplianceAlert alert;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final IconData icon = switch (alert.severity) {
      AlertSeverity.info => Icons.info_outline,
      AlertSeverity.attention => Icons.warning_amber_outlined,
      AlertSeverity.critical => Icons.error_outline,
    };
    final String label = switch (alert.severity) {
      AlertSeverity.info => l10n.alertSeverityInfo,
      AlertSeverity.attention => l10n.alertSeverityAttention,
      AlertSeverity.critical => l10n.alertSeverityCritical,
    };
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    alert.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
