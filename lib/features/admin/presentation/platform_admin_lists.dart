part of 'platform_admin_screen.dart';

/// The three metadata sections: organizations, members, then the audit
/// trail (contract §8 — redacted metadata only).
class _AdminLists extends StatelessWidget {
  const _AdminLists({
    required this.organizations,
    required this.members,
    required this.pendingUserId,
    required this.platformAudit,
    required this.orgAudit,
    required this.selectedAuditOrgId,
    required this.auditLoading,
    required this.auditError,
  });

  final List<OrganizationSummary> organizations;
  final List<OrgMember> members;
  final String? pendingUserId;
  final List<AuditEntry> platformAudit;
  final List<AuditEntry> orgAudit;
  final String? selectedAuditOrgId;
  final bool auditLoading;
  final OrgFailureKind? auditError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceMd,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceXl * 2,
      ),
      children: <Widget>[
        Text(
          l10n.platformAdminOrganizations,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (organizations.isEmpty)
          Text(l10n.stateEmpty)
        else
          ...organizations.map(
            (OrganizationSummary org) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.domain_outlined),
              title: Text(org.name),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(org.createdAt),
              ),
            ),
          ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        Text(
          l10n.platformAdminMembers,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        if (members.isEmpty)
          Text(l10n.stateEmpty)
        else
          ...members.map(
            (OrgMember member) => _MemberRow(
              member: member,
              organizationName: _orgNameFor(
                organizations,
                member.organizationId,
              ),
              pending: member.userId == pendingUserId,
            ),
          ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        Text(
          l10n.platformAdminAudit,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        _AuditSection(
          organizations: organizations,
          platformAudit: platformAudit,
          orgAudit: orgAudit,
          selectedAuditOrgId: selectedAuditOrgId,
          auditLoading: auditLoading,
          auditError: auditError,
        ),
      ],
    );
  }

  static String? _orgNameFor(
    List<OrganizationSummary> organizations,
    String? organizationId,
  ) {
    if (organizationId == null) {
      return null;
    }
    for (final OrganizationSummary org in organizations) {
      if (org.id == organizationId) {
        return org.name;
      }
    }
    return null;
  }
}
