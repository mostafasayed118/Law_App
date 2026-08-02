import 'package:flutter/material.dart';

/// A direction-aware icon that renders [icon] in LTR and [mirroredIcon] under
/// RTL, so forward/back affordances and chevrons follow the reading direction
/// instead of staying hardcoded to one direction.
///
/// Use it for any icon that encodes a direction: "continue" arrows, back
/// buttons, "view all" chevrons (INSTRUCTIONS §4.5: verify RTL mirroring
/// intentionally). All visual parameters are delegated to [Icon]; in LTR it
/// renders exactly what the equivalent plain [Icon] would.
class DirectionalIcon extends StatelessWidget {
  const DirectionalIcon({
    required this.icon,
    required this.mirroredIcon,
    super.key,
    this.size,
    this.fill,
    this.color,
  });

  /// The icon shown under left-to-right text direction.
  final IconData icon;

  /// The icon shown under right-to-left text direction.
  final IconData mirroredIcon;

  final double? size;
  final double? fill;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      rtl ? mirroredIcon : icon,
      size: size,
      fill: fill,
      color: color,
    );
  }
}
