part of 'org_audit_screen.dart';

/// Names the server-side outcome (`allowed`/`denied`) with a localized
/// label; an unexpected value is rendered verbatim (loud, never a silent
/// guess).
class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome, required this.l10n});

  final String outcome;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = switch (outcome) {
      'allowed' => l10n.orgAuditOutcomeAllowed,
      'denied' => l10n.orgAuditOutcomeDenied,
      _ => outcome,
    };
    final Color background = outcome == 'denied'
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.all(Radius.circular(LegalHubTheme.radiusLg)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
