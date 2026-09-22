part of 'ai_research_screen.dart';

/// One advisory finding with its **unconditional citation row** (C-2/B-3).
/// The card carries no tap target and no trailing action — advisory-only
/// means nothing here saves, applies, or exports (C-4/D-3).
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final AiFinding finding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(finding.headline, style: text.titleMedium),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(finding.summary, style: text.bodyMedium),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              finding.excerpt,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: LegalHubTheme.spaceMd),
            // The citation row renders unconditionally — sources are never
            // toggleable (C-2). Static labels, no affordances.
            Text(
              l10n.aiResearchCitationsLabel,
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: LegalHubTheme.spaceXs),
            for (final AiSource source in finding.sources)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  bottom: LegalHubTheme.spaceXs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      source.kind == AiSourceKind.document
                          ? Icons.description_outlined
                          : Icons.folder_outlined,
                      size: 16,
                      color: scheme.outline,
                    ),
                    const SizedBox(width: LegalHubTheme.spaceXs),
                    Expanded(
                      child: Text(
                        '${source.title} — ${source.detail}',
                        style: text.bodySmall,
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
