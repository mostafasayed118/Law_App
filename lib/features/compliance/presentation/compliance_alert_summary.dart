part of 'compliance_alerts_screen.dart';

/// The two Stitch "Overview" and "Dashboard" frames are deliberately merged
/// into this one section above the existing alerts list (owner-approved §3.4).
/// Every number comes from the already-loaded alerts in [ComplianceAlertsState];
/// the Stitch numbers and department/risk charts are not built (no data source).
class _AlertsSummary extends StatelessWidget {
  const _AlertsSummary({required this.alerts});

  final List<ComplianceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int highOpen = alerts
        .where(
          (ComplianceAlert a) =>
              a.status == AlertStatus.open &&
              (a.severity == AlertSeverity.high ||
                  a.severity == AlertSeverity.critical),
        )
        .length;
    // The model has no "investigation" field: acknowledged is the in-review
    // lifecycle stage, so it is the honest mapping for "open investigations".
    final int acknowledged = alerts
        .where((ComplianceAlert a) => a.status == AlertStatus.acknowledged)
        .length;
    final int cleared = alerts
        .where((ComplianceAlert a) => a.status == AlertStatus.resolved)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _AlertStatCard(
                label: l10n.conflictsSummaryHighOpen,
                value: highOpen,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
            Expanded(
              child: _AlertStatCard(
                label: l10n.conflictsSummaryInvestigations,
                value: acknowledged,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
            Expanded(
              child: _AlertStatCard(
                label: l10n.conflictsSummaryCleared,
                value: cleared,
              ),
            ),
          ],
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
      ],
    );
  }
}

class _AlertStatCard extends StatelessWidget {
  const _AlertStatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: LegalHubTheme.space2xs),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
