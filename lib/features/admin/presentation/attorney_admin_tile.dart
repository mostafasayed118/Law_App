part of 'attorney_admin_screen.dart';

class _AttorneyAdminTile extends StatelessWidget {
  const _AttorneyAdminTile({required this.attorney});

  final Attorney attorney;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> details = <String>[
      if (attorney.headline != null) attorney.headline!,
      if (attorney.city != null) attorney.city!,
    ];
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
        onTap: () => _openForm(context, initial: attorney),
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
                    const SizedBox(height: LegalHubTheme.spaceXs),
                    LabelChip(
                      label: attorney.isActive
                          ? l10n.attorneyStatusActive
                          : l10n.attorneyStatusInactive,
                      background: attorney.isActive
                          ? scheme.secondaryContainer
                          : scheme.errorContainer,
                      foreground: attorney.isActive
                          ? scheme.onSecondaryContainer
                          : scheme.onErrorContainer,
                    ),
                  ],
                ),
              ),
              if (attorney.isActive)
                IconButton(
                  onPressed: () => _confirmDeactivate(context, attorney),
                  tooltip: l10n.attorneyAdminDeactivate,
                  icon: const Icon(Icons.person_off_outlined),
                  color: scheme.error,
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

  Future<void> _confirmDeactivate(
    BuildContext context,
    Attorney attorney,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.attorneyAdminDeactivateTitle,
      content: Text(l10n.attorneyAdminDeactivateBody(attorney.name)),
      confirmLabel: l10n.attorneyAdminDeactivate,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AttorneyAdminCubit cubit = context.read<AttorneyAdminCubit>();
    final bool ok = await cubit.deactivate(attorney.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attorneyAdminDeactivateFailed)),
      );
    }
  }
}
