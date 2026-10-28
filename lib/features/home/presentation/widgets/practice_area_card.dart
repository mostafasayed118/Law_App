import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';

/// A practice-area card with an icon chip and a title, used in the home
/// dashboard's horizontal scroll.
class PracticeAreaCard extends StatelessWidget {
  const PracticeAreaCard({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const double _cardWidth = 160;
  static const double _cardHeight = 192;
  static const double _iconSize = 40;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Min-height (not a fixed 192) so the label can grow at large text
        // scales instead of overflowing; the bottom-aligned column keeps the
        // original visual posture at the default scale.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _cardWidth,
            maxWidth: _cardWidth,
            minHeight: _cardHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
            child: Column(
              // min + the ConstrainedBox floor: short labels keep the original
              // 192px card with the content bottom-aligned, long ones grow.
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: _iconSize,
                  height: _iconSize,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: LegalHubTheme.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 22, color: scheme.onPrimary, fill: 1),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
