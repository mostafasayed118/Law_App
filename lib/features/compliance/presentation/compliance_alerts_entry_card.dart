import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the compliance-alerts list (`/alerts`, v1 queue
/// 2026-08-09). Navigation hint only; nav hint semantics.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class ComplianceAlertsEntryCard extends StatelessWidget {
  const ComplianceAlertsEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.shield_outlined,
      title: l10n.alertsEntryTitle,
      subtitle: l10n.alertsEntrySubtitle,
      onTap: onTap,
    );
  }
}
