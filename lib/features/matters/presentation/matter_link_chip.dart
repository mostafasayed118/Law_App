import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';

/// The Phase 12 reverse cross-link affordance: a compact "View matter" chip
/// that is the **only tap target** in a vault/messages row (D-C2).
///
/// Deliberately NOT a chevron / download / visibility / open_in_new
/// affordance — the Phase 8/9 AC-2 absence lines stay meaningful: this is a
/// small labeled chip with a folder icon, never a row-level action. The
/// parent surface decides whether a row gets one (D-C2/D-C4: only when the
/// `matterRef` resolves and the `canViewMatters` nav hint is granted); the
/// chip only carries the navigation itself.
class MatterLinkChip extends StatelessWidget {
  const MatterLinkChip({required this.onTap, super.key});

  /// Navigates to the resolved matter's details route (`/matters/:matterId`).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusFull),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LegalHubTheme.spaceSm,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.folder_open,
                size: 14,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.viewMatter,
                style: text.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
