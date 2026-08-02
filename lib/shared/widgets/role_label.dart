import 'package:flutter/material.dart';

import '../../core/roles/user_role.dart';
import '../../l10n/app_localizations.dart';

/// Canonical localized display label for a [UserRole].
///
/// ADR-0004 second use: the settings and profile screens previously each
/// owned an identical private mapping (each flagged as a shared-extraction
/// follow-up); this is the single source of truth. A null role maps to the
/// client label, matching the demo-session default.
String roleLabel(AppLocalizations l10n, UserRole? role) {
  return switch (role) {
    UserRole.attorney => l10n.roleAttorney,
    UserRole.partner => l10n.rolePartner,
    UserRole.complianceOfficer => l10n.roleComplianceOfficer,
    UserRole.researchAnalyst => l10n.roleResearchAnalyst,
    UserRole.admin => l10n.roleAdmin,
    UserRole.client || null => l10n.roleClient,
  };
}

/// Renders the localized label of the active membership's [role].
///
/// This is a UX-only projection of the session's organization-scoped role —
/// never an authorization grant (INSTRUCTIONS §1.3). Use it anywhere a role
/// name is surfaced to the user.
class RoleLabel extends StatelessWidget {
  const RoleLabel({required this.role, this.style, super.key});

  final UserRole? role;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(roleLabel(AppLocalizations.of(context), role), style: style);
  }
}
