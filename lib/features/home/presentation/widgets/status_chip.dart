import 'package:flutter/material.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../shared/formatting/display_case.dart';

/// Small all-caps status chip ("ACTIVE CASE", "ACTION REQUIRED", …).
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.background,
    this.foreground,
    super.key,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        displayUppercase(label, Localizations.localeOf(context)),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground ?? scheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
