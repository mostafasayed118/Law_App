import 'package:flutter/material.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// A bordered social-sign-in button with a leading brand icon.
///
/// Presentational only — the [onTap] callback decides routing.
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

/// An [ElevatedButton] that shows a small spinner in place of its label while
/// [loading] is true and is disabled in that state.
class LoadingElevatedButton extends StatelessWidget {
  const LoadingElevatedButton({
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.icon,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget content = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon == null
              ? Text(label)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label),
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ));
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: content,
    );
  }
}

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

/// A fixed-bottom pill badge stating the connection is encrypted.
///
/// Presentational only — it does not assert any real transport guarantee.
class SecurityBadge extends StatelessWidget {
  const SecurityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          bottom: LegalHubTheme.spaceMd,
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: LegalHubTheme.spaceMd,
              vertical: LegalHubTheme.spaceXs,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.all(
                Radius.circular(LegalHubTheme.radiusFull),
              ),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: scheme.secondary,
                ),
                const SizedBox(width: LegalHubTheme.spaceXs),
                Text(
                  l10n.encryptedConnectionNotice,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: scheme.onSurfaceVariant,
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
