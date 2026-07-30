import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// A horizontal divider with a centered label ("OR CONTINUE WITH").
class EditorialDivider extends StatelessWidget {
  const EditorialDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(child: Container(height: 1, color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LegalHubTheme.spaceMd,
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.outline),
          ),
        ),
        Expanded(child: Container(height: 1, color: scheme.outlineVariant)),
      ],
    );
  }
}
