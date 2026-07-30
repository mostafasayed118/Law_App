import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';

/// A fixed-bottom pill badge stating the connection is encrypted.
///
/// Displayed at the bottom of the auth screens to reassure the user.
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
