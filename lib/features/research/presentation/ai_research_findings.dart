part of 'ai_research_screen.dart';

/// The findings arm. Every failure renders its typed copy — a denial has no
/// retry, an outage does — and `provider_not_configured` is handled by the
/// empty arm as an explicit unavailable state (never a fake result).
class _FindingsSection extends StatelessWidget {
  const _FindingsSection({required this.state, required this.onRetry});

  final AiResearchState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return switch (state.findings) {
      ViewLoading<List<AiFinding>>() => const Padding(
        padding: EdgeInsetsDirectional.symmetric(
          vertical: LegalHubTheme.spaceXl,
        ),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewUnauthorized<List<AiFinding>>() => _TypedErrorState(
        message: _errorMessage(l10n, state.lastError),
      ),
      ViewOffline<List<AiFinding>>() || ViewError<List<AiFinding>>() =>
        _TypedErrorState(
          message: _errorMessage(l10n, state.lastError),
          onRetry: onRetry,
        ),
      ViewEmpty<List<AiFinding>>() => _EmptyAnswer(state: state),
      ViewSuccess<List<AiFinding>>(data: final List<AiFinding> data)
          when data.isEmpty =>
        _EmptyAnswer(state: state),
      ViewSuccess<List<AiFinding>>(data: final List<AiFinding> data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AiFinding finding in data)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: LegalHubTheme.spaceSm,
              ),
              child: _FindingCard(finding: finding),
            ),
        ],
      ),
    };
  }
}

/// Maps the preserved wire code to the typed, localized copy. Unknown codes
/// fall back to the generic research error rather than leaking provider text.
String _errorMessage(AppLocalizations l10n, AppError? error) {
  return switch (error?.code) {
    'unauthorized' => l10n.aiResearchErrorUnauthorized,
    'forbidden' => l10n.aiResearchErrorForbidden,
    'invalid_request' => l10n.aiResearchErrorInvalidRequest,
    'context_too_large' => l10n.aiResearchErrorContextTooLarge,
    'provider_unavailable' => l10n.aiResearchErrorProviderUnavailable,
    'invalid_response' => l10n.aiResearchErrorInvalidResponse,
    _ => l10n.aiResearchError,
  };
}

class _TypedErrorState extends StatelessWidget {
  const _TypedErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: LegalHubTheme.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

/// The honest unavailable state for a deployment without `RIVER_API_KEY`.
/// No retry: the secret is server-side configuration, not a transient fault.
class _ProviderNotConfigured extends StatelessWidget {
  const _ProviderNotConfigured();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: LegalHubTheme.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 36, color: scheme.outline),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.aiResearchProviderNotConfigured,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
