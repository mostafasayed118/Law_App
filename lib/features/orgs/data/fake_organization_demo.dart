part of 'fake_organization_gateway.dart';

/// The cross-fake demo data providers (not part of the
/// [OrganizationGateway] interface): the platform-admin metadata mirrors
/// and the membership hydration input. A library-private mixin applied
/// by the gateway, so its public members stay real class members for
/// the fakes' and tests' external call sites.
mixin _FakeOrgDemo on _FakeOrgState {
  /// Metadata-only cross-org listing (P3.5): every organization in the
  /// registry — the mirror of `list_organizations_metadata`. Metadata only,
  /// never content.
  List<OrganizationSummary> allOrganizations() =>
      _orgs.values.toList(growable: false);

  /// Metadata-only cross-org member listing (P3.5): every membership across
  /// orgs as [OrgMember] rows — the mirror of `list_members_metadata`. The
  /// real RPC joins `profiles`, so invited rows (no profile yet) never
  /// appear; the fake excludes rows carrying an [OrgMember.invitationId].
  List<OrgMember> allMembers() {
    final List<OrgMember> members = <OrgMember>[];
    for (final Map<String, OrgMember> roster in _members.values) {
      for (final OrgMember member in roster.values) {
        if (member.invitationId != null) {
          continue;
        }
        members.add(member);
      }
    }
    return members;
  }

  /// Mirrors `delete_demo_account`'s cascade (P3.5): removes [userId] from
  /// every roster (profiles/memberships cascade server-side; audit rows
  /// survive). Never invoked with the demo identity by the platform fake
  /// (the RPC refuses `auth.uid()`).
  void deleteAccount(String userId) {
    for (final Map<String, OrgMember> roster in _members.values) {
      roster.remove(userId);
    }
  }

  /// Derives the demo user's current memberships from this fake's internal
  /// state (P3.3 Slice B).
  ///
  /// Reads every roster for the demo identity — mirroring the RLS-scoped
  /// memberships SELECT, which returns the caller's own rows across
  /// organizations regardless of status — and resolves each org's display
  /// name from the registry. [FakeMembershipRepository] reads this when
  /// bound to the same instance, so an org created during an env-less run
  /// joins the hydrated session without a static re-seed. This is a seam
  /// for tests and env-less runs; it is not an authorization mechanism.
  List<OrganizationMembership> demoUserMemberships() {
    final List<OrganizationMembership> memberships = <OrganizationMembership>[];
    for (final MapEntry<String, Map<String, OrgMember>> entry
        in _members.entries) {
      final OrgMember? me = entry.value[FakeOrganizationGateway.demoUserId];
      if (me == null) {
        continue;
      }
      memberships.add(
        OrganizationMembership(
          organizationId: entry.key,
          organizationName: _orgs[entry.key]?.name,
          role: me.role,
          status: me.status,
        ),
      );
    }
    return memberships;
  }
}
