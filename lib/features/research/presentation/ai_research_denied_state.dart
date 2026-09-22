part of 'ai_research_screen.dart';

/// Distinct D-R1 denial: the research surface is a legal-team-facing demo
/// (owner decision 2026-09-02). No retry — the gate is the role, not a
/// transient failure. The persistent banner stays off here: the denied
/// caller never reached the advisory surface (C-3 governs its renders).
class _DeniedState extends StatelessWidget {
  const _DeniedState();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LegalHubTheme.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              l10n.stateUnauthorized,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
