import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the booking wizard (Phase 5 slice 5.2).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canBookConsultation]. Tapping navigates to the `/book`
/// route. The entry is a navigation hint only — like every capability flag in
/// this bootstrap, it is never an authorization grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class BookingEntryCard extends StatelessWidget {
  const BookingEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.event_available_outlined,
      title: l10n.bookingEntryTitle,
      subtitle: l10n.bookingEntrySubtitle,
      onTap: onTap,
    );
  }
}
