import 'package:flutter/material.dart';

/// A 96px circular "hero" badge with a centered icon, used at the top of
/// confirmation/recovery screens to introduce the flow visually.
class IconHeroBadge extends StatelessWidget {
  const IconHeroBadge({
    required this.icon,
    this.iconColor,
    this.background,
    this.size = 96,
    this.iconSize = 48,
    super.key,
  });

  final IconData icon;
  final Color? iconColor;
  final Color? background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: iconColor ?? scheme.primary),
    );
  }
}
