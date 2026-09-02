import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the AI research-assistant surface
/// (`/research`; AI research slice 1.1, plan 2026-09-02).
///
/// Rendered on the home screen when the session's role grants
/// [RoleCapability.canUseAiResearch] — **attorney, researchAnalyst, and
/// partner only** (owner decision D-R1, 2026-09-02: the research surface
/// faces the legal team; client/compliance/admin roles do not see the
/// entry). Like every capability flag in this product, it is a navigation
/// hint only — never an authorization grant; the demo surface itself is
/// client-side synthetic data with no server boundary to enforce (D-1).
class AiResearchEntryCard extends StatelessWidget {
  const AiResearchEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.auto_awesome_outlined,
      title: l10n.aiResearchEntryTitle,
      subtitle: l10n.aiResearchEntrySubtitle,
      onTap: onTap,
    );
  }
}
