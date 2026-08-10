import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the matter dashboard (Phase 7, 7.1).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canViewMatters] (owner decision D-M6). Tapping navigates
/// to the `/matters` route. The entry is a navigation hint only — like every
/// capability flag in this bootstrap, it is never an authorization grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class MatterEntryCard extends StatelessWidget {
  const MatterEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.folder_copy_outlined,
      title: l10n.matterEntryTitle,
      subtitle: l10n.matterEntrySubtitle,
      onTap: onTap,
    );
  }
}
