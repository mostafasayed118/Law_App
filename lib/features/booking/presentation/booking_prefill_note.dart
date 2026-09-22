part of 'booking_screen.dart';

class _PrefillNote extends StatelessWidget {
  const _PrefillNote({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
      ),
      child: Text(
        l10n.bookingAttorneyPrefill(name),
        style: text.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
