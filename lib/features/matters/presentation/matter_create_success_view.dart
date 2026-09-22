part of 'matter_create_screen.dart';

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.matterId, required this.onDone});

  final String matterId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 48, color: scheme.primary),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(l10n.matterCreateSuccessTitle, style: text.titleLarge),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(l10n.matterCreateSuccessBody(matterId), style: text.bodyMedium),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.matterCreateSuccessNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          FilledButton(onPressed: onDone, child: Text(l10n.matterCreateDone)),
        ],
      ),
    );
  }
}
