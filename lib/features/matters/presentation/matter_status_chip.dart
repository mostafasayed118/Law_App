import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// Small colored chip rendering a matter's lifecycle status.
///
/// Shared by the list tile and the details surface (both within the matters
/// feature — the roster's private-chip pattern generalized to the second
/// surface that needs it; feature-local, never a home import).
class MatterStatusChip extends StatelessWidget {
  const MatterStatusChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
