part of 'booking_screen.dart';

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Flexible label (wraps instead of overflowing at narrow widths or
          // large text scales) with the value taking the remaining space.
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: LegalHubTheme.spaceMd),
          Expanded(flex: 3, child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
