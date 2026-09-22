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
    // The org-name lookup is a Map, not a scan (audit 2026-09-21, H-8): the
    // previous version resolved each member's org name with a linear scan of
    // organizations — O(members × orgs) per build over the two collections
    // the admin RPCs return unbounded.
    final Map<String, String> orgNames = <String, String>{
      for (final OrganizationSummary org in organizations) org.id: org.name,
    };

    // One lazily-built list with a flat index space (the M-20 pattern): rows
    // are constructed on demand instead of mapping every org and member into
    // children up front, so row culling applies to the sections the admin RPCs
    // feed.
    final int orgSlots = organizations.isEmpty ? 1 : organizations.length;
    final int memberSlots = members.isEmpty ? 1 : members.length;
    final int membersGap = 2 + orgSlots; // 0 orgs header, 1 gap
    final int membersHeader = membersGap + 1;
    final int memberFirst = membersHeader + 2; // gap, members header
    final int auditGap = memberFirst + memberSlots;

    return ListView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceMd,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceXl * 2,
      ),
      itemCount: auditGap + 4, // gap, audit header, gap, audit section
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Text(
            l10n.platformAdminOrganizations,
            style: Theme.of(context).textTheme.headlineSmall,
          );
        }
        if (index == 1) {
          return const SizedBox(height: LegalHubTheme.spaceSm);
        }
        final int orgIndex = index - 2;
        if (orgIndex < orgSlots) {
          return organizations.isEmpty
              ? Text(l10n.stateEmpty)
              : _orgTile(organizations[orgIndex], context);
        }
        if (index == membersGap) {
          return const SizedBox(height: LegalHubTheme.spaceXl);
        }
        if (index == membersHeader) {
          return Text(
            l10n.platformAdminMembers,
            style: Theme.of(context).textTheme.headlineSmall,
          );
        }
        if (index == membersHeader + 1) {
          return const SizedBox(height: LegalHubTheme.spaceSm);
        }
        final int memberIndex = index - memberFirst;
        if (memberIndex < memberSlots) {
          final OrgMember member = members[memberIndex];
          return members.isEmpty
              ? Text(l10n.stateEmpty)
              : _MemberRow(
                  member: member,
                  organizationName: orgNames[member.organizationId],
                  pending: member.userId == pendingUserId,
                );
        }
        final int tail = index - auditGap;
        if (tail == 0) {
          return const SizedBox(height: LegalHubTheme.spaceXl);
        }
        if (tail == 1) {
          return Text(
            l10n.platformAdminAudit,
            style: Theme.of(context).textTheme.headlineSmall,
          );
        }
        if (tail == 2) {
          return const SizedBox(height: LegalHubTheme.spaceSm);
        }
        return _AuditSection(
          organizations: organizations,
          platformAudit: platformAudit,
          orgAudit: orgAudit,
          selectedAuditOrgId: selectedAuditOrgId,
          auditLoading: auditLoading,
          auditError: auditError,
        );
      },
    );
  }

  Widget _orgTile(OrganizationSummary org, BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.domain_outlined),
    title: Text(org.name),
    subtitle: Text(
      MaterialLocalizations.of(context).formatShortDate(org.createdAt),
    ),
  );
}
