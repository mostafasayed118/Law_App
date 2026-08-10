part of 'booking_screen.dart';

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.icon,
    required this.label,
    this.trailingLabel,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: scheme.onSurfaceVariant, fill: 1),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Text(
                  label,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (selected) const SizedBox(width: LegalHubTheme.spaceSm),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
