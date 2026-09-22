part of 'platform_admin_screen.dart';

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
