import 'package:flutter/material.dart';

import '../../../shared/widgets/label_chip.dart';

/// Small colored chip rendering a matter's lifecycle status.
///
/// Shared by the list tile and the details surface (both within the matters
/// feature — the roster's private-chip pattern generalized to the second
/// surface that needs it; feature-local, never a home import).
///
/// E5 wrapper: the visual shell is the shared [LabelChip]; this class keeps
/// the feature's secondary-container colors and the public name the list
/// tiles construct by type.
class MatterStatusChip extends StatelessWidget {
  const MatterStatusChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LabelChip(
      label: label,
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
    );
  }
}
