import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../forms/validators.dart';

/// Live password-strength indicator for the auth forms.
///
/// Renders the coarse [PasswordStrength] tier of the current field value as a
/// compact icon + label row. The label and icon are the primary signal —
/// color is only an enhancement (the auth forms never rely on color alone;
/// ADR-0002 dark-theme posture). Hidden entirely while the field is empty so
/// an untouched form stays quiet.
///
/// Consumers wrap it in a `ValueListenableBuilder` on the password
/// [TextEditingController] (or drive it with their own rebuild) so it updates
/// as the user types without owning the field's state.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({required this.value, super.key});

  /// The current password field value; empty hides the indicator.
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    final PasswordStrength strength = LegalHubValidators.passwordStrength(
      value,
    );
    final (IconData icon, Color color, String label) = switch (strength) {
      PasswordStrength.weak => (
        Icons.shield_outlined,
        scheme.error,
        l10n.passwordStrengthWeak,
      ),
      PasswordStrength.fair => (
        Icons.shield_outlined,
        scheme.tertiary,
        l10n.passwordStrengthFair,
      ),
      PasswordStrength.strong => (
        Icons.verified_user_outlined,
        scheme.primary,
        l10n.passwordStrengthStrong,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: LegalHubTheme.spaceXs),
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
