part of 'ai_research_screen.dart';

/// The idle prompt (no query submitted yet) and the honest no-match empty
/// state share this arm — the [AiResearchState.lastQuery] distinguishes the
/// two. The persistent banner lives above this widget, so both states keep
/// it on-screen (C-3).
class _IdleOrNoMatch extends StatelessWidget {
  const _IdleOrNoMatch({required this.state});

  final AiResearchState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: Center(
        child: Text(
          state.lastQuery.isEmpty
              ? l10n.aiResearchIdlePrompt
              : l10n.aiResearchNoMatches,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
