part of 'ai_research_screen.dart';

/// One advisory finding with its **unconditional citation row** (C-2/B-3).
/// The card carries no tap target and no trailing action — advisory-only
/// means nothing here saves, applies, or exports (C-4/D-3).
///
/// Localized prose recomposed from the citation sources (demo localization,
/// 2026-09-24). Sources are non-empty by contract (C-2); any other shape
/// falls back to the gateway's static strings.
typedef _LocalizedFinding = ({String headline, String summary, String excerpt});

_LocalizedFinding _localizeFinding(AppLocalizations l10n, AiFinding finding) {
  if (finding.sources.isEmpty) {
    return (
      headline: finding.headline,
      summary: finding.summary,
      excerpt: finding.excerpt,
    );
  }
  final AiSource first = finding.sources.first;
  final String title = demoCorpusTitle(l10n, first.title);
  if (first.kind == AiSourceKind.document) {
    final String ref = finding.sources.length > 1
        ? demoCorpusTitle(l10n, finding.sources[1].title)
        : '';
    return (
      headline: l10n.researchHeadline(title),
      summary: l10n.researchSummaryDoc(title, ref),
      excerpt: l10n.researchExcerptDoc(
        demoSourceDetail(l10n, first.detail),
        ref,
      ),
    );
  }
  final String area = demoSourceDetail(l10n, first.detail);
  return (
    headline: l10n.researchHeadline(title),
    summary: l10n.researchSummaryMatter(title, area),
    excerpt: l10n.researchExcerptMatter(area),
  );
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final AiFinding finding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // Demo localization (2026-09-24): the gateway ships static EN copy, so
    // the card recomposes the prose from the structured citation sources
    // through localized templates. An unexpected shape falls back to the
    // gateway strings (never blank).
    final _LocalizedFinding copy = _localizeFinding(l10n, finding);
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
            Text(copy.headline, style: text.titleMedium),
            const SizedBox(height: LegalHubTheme.spaceXs),
            Text(copy.summary, style: text.bodyMedium),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              copy.excerpt,
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
                        '${demoCorpusTitle(l10n, source.title)} — '
                        '${demoSourceDetail(l10n, source.detail)}',
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
