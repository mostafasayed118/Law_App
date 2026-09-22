part of 'home_screen.dart';

List<Widget> _homeActivityCards(BuildContext context) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final TextTheme text = Theme.of(context).textTheme;
  return <Widget>[
    IdentityCard(
      accentColor: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              StatusChip(label: l10n.activeCaseChip),
              // Flexible + ellipsis keeps the timestamp on-screen when the
              // row is squeezed by a transient narrow layout or a large
              // text scale.
              Flexible(
                child: Text(
                  l10n.activeCaseTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(l10n.activeCaseTitle, style: text.headlineMedium),
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            l10n.activeCaseBody,
            style: text.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 14,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: LegalHubTheme.spaceSm),
                    Expanded(
                      child: Text(
                        l10n.activeCaseAttorney,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceSm),
              DirectionalIcon(
                icon: Icons.chevron_right,
                mirroredIcon: Icons.chevron_left,
                color: scheme.outline,
              ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: LegalHubTheme.spaceMd),
    _InfoRow(
      icon: Icons.description_outlined,
      iconColor: scheme.onErrorContainer,
      iconBg: scheme.errorContainer,
      title: l10n.actionRequiredTitle,
      body: l10n.actionRequiredBody,
    ),
    const SizedBox(height: LegalHubTheme.spaceMd),
    _InfoRow(
      icon: Icons.event_outlined,
      iconColor: scheme.primary,
      iconBg: scheme.surfaceContainerHighest,
      title: l10n.consultationTitle,
      body: l10n.consultationBody,
    ),
  ];
}
