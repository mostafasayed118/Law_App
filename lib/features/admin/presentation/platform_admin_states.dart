part of 'platform_admin_screen.dart';

/// Distinct non-owner state: the owner-only RPCs denied server-side. Never
/// rendered as an empty-success list (AC-7); no retry — the gate is
/// identity, not a transient failure.
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
            const SizedBox(height: LegalHubTheme.spaceSm),
            Text(
              orgErrorMessage(l10n, OrgFailureKind.denied),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A non-denial failure with a retry (transient, unlike the denied gate).
class _FailedState extends StatelessWidget {
  const _FailedState({required this.kind});

  final OrgFailureKind kind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.error_outline,
            size: 32,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(orgErrorMessage(l10n, kind), textAlign: TextAlign.center),
          const SizedBox(height: LegalHubTheme.spaceSm),
          TextButton(
            onPressed: () => context.read<PlatformAdminCubit>().load(),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
