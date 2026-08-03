import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Home-dashboard entry into the matter dashboard (Phase 7, 7.1).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canViewMatters] (owner decision D-M6). Tapping navigates
/// to the `/matters` route. The entry is a navigation hint only — like every
/// capability flag in this bootstrap, it is never an authorization grant.
class MatterEntryCard extends StatelessWidget {
  const MatterEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.folder_copy_outlined,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                  fill: 1,
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.matterEntryTitle,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.matterEntrySubtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
