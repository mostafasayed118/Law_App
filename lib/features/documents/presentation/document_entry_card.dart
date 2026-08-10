import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the document vault (Phase 8, slice 8.1).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canViewDocuments] (owner decision D-V5). Tapping
/// navigates to the `/vault` route. The entry is a navigation hint only —
/// like every capability flag in this bootstrap, it is never an
/// authorization grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class DocumentEntryCard extends StatelessWidget {
  const DocumentEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.description_outlined,
      title: l10n.vaultEntryTitle,
      subtitle: l10n.vaultEntrySubtitle,
      onTap: onTap,
    );
  }
}
