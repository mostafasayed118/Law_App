part of 'org_audit_screen.dart';

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
    final String issued = formatMediumDate(
      l10n,
      entry.serverTimestamp.toLocal(),
    );
    // At extreme text scales the fixed-intrinsic outcome chip plus the
    // action label no longer share a line (50px right overflow at 3.0).
    // Above 2.0 the chip drops to its own line instead of truncating either
    // the action name or the outcome.
    final bool stackOutcome = MediaQuery.textScalerOf(context).scale(12) > 24;
    final Widget actionTitle = Row(
      children: <Widget>[
        Icon(Icons.receipt_long_outlined, size: 18, color: scheme.primary),
        const SizedBox(width: LegalHubTheme.spaceSm),
        Expanded(child: Text(entry.action, style: text.titleSmall)),
        if (!stackOutcome) ...<Widget>[
          // Server vocabulary rendered verbatim; color is never the sole
          // carrier (the chip also names the outcome).
          _OutcomeChip(outcome: entry.outcome, l10n: l10n),
        ],
      ],
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(LegalHubTheme.radiusLg)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            actionTitle,
            if (stackOutcome) ...<Widget>[
              const SizedBox(height: LegalHubTheme.spaceXs),
              _OutcomeChip(outcome: entry.outcome, l10n: l10n),
            ],
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(
              labels.auditSummary(entry.redactedSummary),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            // Redacted metadata only: timestamp + correlation id (when the
            // server supplies one) — never content or credentials.
            Text(
              entry.correlationId == null
                  ? issued
                  : '$issued · ${entry.correlationId}',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
