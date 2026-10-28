part of 'attorney_search_screen.dart';

class _AttorneyTile extends StatelessWidget {
  const _AttorneyTile({
    required this.attorney,
    required this.localOnly,
    required this.onTap,
  });

  final Attorney attorney;
  final bool localOnly;

  /// Phase 6 slice 6.2: tapping a row opens the attorney profile route.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> details = _details(l10n);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  attorney.name.isEmpty
                      ? '?'
                      : attorney.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      attorney.name,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final String line in details) ...<Widget>[
                      const SizedBox(height: LegalHubTheme.space2xs),
                      Text(
                        line,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DirectionalIcon(
                icon: Icons.chevron_right,
                mirroredIcon: Icons.chevron_left,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The metadata line under the name. Synthetic rows keep the exact
  /// "area · locale" line; a real row with neither falls back to its headline
  /// or city (one line, so the row height stays stable).
  List<String> _details(AppLocalizations l10n) {
    final List<String> summary = <String>[
      if (attorney.practiceArea != null)
        practiceAreaLabel(l10n, attorney.practiceArea!),
      if (attorney.locale.isNotEmpty) attorney.locale,
    ];
    if (summary.isNotEmpty) {
      return <String>[summary.join(' · ')];
    }
    final String fallback = attorney.headline ?? attorney.city ?? '';
    final String detail = DemoLabels(
      l10n,
      localOnly: localOnly,
    ).attorneyHeadline(fallback);
    return detail.isEmpty ? const <String>[] : <String>[detail];
  }
}
