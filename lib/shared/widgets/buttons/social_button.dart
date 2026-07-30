import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// A bordered social-sign-in button with a leading brand icon.
///
/// Extracted from the sign-in screen's private `_SocialButton` so future auth
/// flows can reuse it. Presentational only — the [onTap] callback decides
/// routing.
class SocialButton extends StatelessWidget {
  const SocialButton({
    required this.label,
    required this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LegalHubTheme.spaceSm,
          vertical: 12,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LegalHubTheme.radiusLg),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
