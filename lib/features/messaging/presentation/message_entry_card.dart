import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the thread list (Phase 9, slice 9.1).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canViewMessages] (owner decision D-MSG5). Tapping
/// navigates to the `/messages` route. The entry is a navigation hint only —
/// like every capability flag in this bootstrap, it is never an
/// authorization grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class MessageEntryCard extends StatelessWidget {
  const MessageEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.forum_outlined,
      title: l10n.messagesEntryTitle,
      subtitle: l10n.messagesEntrySubtitle,
      onTap: onTap,
    );
  }
}
