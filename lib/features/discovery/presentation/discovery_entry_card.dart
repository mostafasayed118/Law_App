import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the attorney-discovery search (Phase 6, 6.1).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canViewAttorneyDiscovery] (owner decision D-A6). Tapping
/// navigates to the `/discovery` route. The entry is a navigation hint only —
/// like every capability flag in this bootstrap, it is never an authorization
/// grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class DiscoveryEntryCard extends StatelessWidget {
  const DiscoveryEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.person_search_outlined,
      title: l10n.discoveryEntryTitle,
      subtitle: l10n.discoveryEntrySubtitle,
      onTap: onTap,
    );
  }
}
