part of 'ai_research_screen.dart';

/// The idle prompt (no request submitted yet), the honest no-findings state,
/// and the explicit provider-not-configured state. The first two are
/// distinguished by [AiResearchState.lastQuery]; the third by the preserved
/// typed code. The persistent banner lives above this widget, so every state
/// keeps it on-screen (C-3).
class _EmptyAnswer extends StatelessWidget {
  const _EmptyAnswer({required this.state});

  final AiResearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.lastError?.code == ResearchWireCodes.providerNotConfigured) {
      return const _ProviderNotConfigured();
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String copy;
    if (state.lastQuery.isEmpty) {
      copy = backendIsLocalOnly
          ? l10n.aiResearchIdlePrompt
          : l10n.aiResearchIdlePromptReal;
    } else {
      copy = backendIsLocalOnly
          ? l10n.aiResearchNoMatches
          : l10n.aiResearchNoMatchesConfigured;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceLg),
      child: Center(
        child: Text(
          copy,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
