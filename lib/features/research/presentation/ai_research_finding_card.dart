part of 'ai_research_screen.dart';

/// One advisory finding with its **unconditional citation row** (C-2/B-3).
/// The card carries no tap target and no trailing action — advisory-only
/// means nothing here saves, applies, or exports (C-4/D-3).
///
/// Synthetic findings are recomposed through localized demo templates; real
/// findings carry the model's own prose and the server's source id, so they
/// render as-is with a localized source-kind label. A `none` source renders
/// the honest "no source cited" line instead of inventing a citation.
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
  if (first.kind == AiSourceKind.none || first.title.isEmpty) {
    return (
      headline: finding.headline,
      summary: finding.summary,
      excerpt: finding.excerpt,
    );
  }
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

String _sourceLabel(AppLocalizations l10n, AiSource source) {
  switch (source.kind) {
    case AiSourceKind.none:
      return l10n.aiResearchNoSourceCited;
    case AiSourceKind.document:
    case AiSourceKind.matter:
      if (source.title.isNotEmpty) {
        return '${demoCorpusTitle(l10n, source.title)} — '
            '${demoSourceDetail(l10n, source.detail)}';
      }
      final String kindLabel = source.kind == AiSourceKind.document
          ? l10n.aiResearchSourceDocument
          : l10n.aiResearchSourceMatter;
      return source.sourceId == null
          ? kindLabel
          : '$kindLabel — ${source.sourceId}';
  }
}

IconData _sourceIcon(AiSourceKind kind) => switch (kind) {
  AiSourceKind.document => Icons.description_outlined,
  AiSourceKind.matter => Icons.folder_outlined,
  AiSourceKind.none => Icons.link_off,
};

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final AiFinding finding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // The gateway ships static EN copy for the demo, so the card recomposes
    // the prose from the structured citation sources through localized
    // templates. An unexpected shape falls back to the gateway strings
    // (never blank).
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
            if (copy.excerpt.isNotEmpty) ...<Widget>[
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(
                copy.excerpt,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
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
            if (finding.sources.isEmpty)
              Text(
                l10n.aiResearchNoSourceCited,
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final AiSource source in finding.sources)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: LegalHubTheme.spaceXs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        _sourceIcon(source.kind),
                        size: 16,
                        color: scheme.outline,
                      ),
                      const SizedBox(width: LegalHubTheme.spaceXs),
                      Expanded(
                        child: Text(
                          _sourceLabel(l10n, source),
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
