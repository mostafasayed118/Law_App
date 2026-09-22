part of 'fake_organization_gateway.dart';

/// The account/audit/accept group of [FakeOrganizationGateway] — the
/// same method bodies moved verbatim.
mixin _FakeOrgAdmin on _FakeOrgState {
  Future<OrgOutcome<void>> deleteMyAccount() async {
    // Mirrors the server cascade: profiles/memberships of the caller vanish;
    // organizations keep their rows with created_by/actor cleared (the fake
    // has no cross-entity actor columns beyond the demo identity).
    for (final Map<String, OrgMember> roster in _members.values) {
      roster.remove(FakeOrganizationGateway.demoUserId);
    }
    return const OrgOutcome<void>.success(null);
  }

  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    // Mirrors the server's member-gate: an org the caller has no membership
    // in reads as the undifferentiated denied (never empty success — the
    // P3.5 AC-7 posture). A known org with no events yet is an honest empty
    // trail (fresh orgs have nothing to audit).
    if (!_members.containsKey(organizationId)) {
      return const OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<AuditEntry>>.success(
      _audit[organizationId] ?? const <AuditEntry>[],
    );
  }

  Future<OrgOutcome<String>> acceptInvitation({required String token}) async {
    final _FakeInvitation? invitation = _invitations.values
        .where(
          (_FakeInvitation inv) =>
              inv.status == _FakeInvitationStatus.pending && inv.token == token,
        )
        .firstOrNull;
    // Mirrors the server's undifferentiated denial: unknown/expired tokens
    // and email mismatches all read as "invalid invitation".
    if (invitation == null ||
        invitation.email !=
            FakeOrganizationGateway.demoUserEmail.toLowerCase()) {
      return const OrgOutcome<String>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );
    }
    invitation.status = _FakeInvitationStatus.accepted;
    final Map<String, OrgMember> roster = _members[invitation.organizationId]!;
    // The pending invited row (keyed by email) becomes the real membership
    // with the SERVER-OWNED role from the invitation.
    roster.remove(invitation.email);
    roster[FakeOrganizationGateway.demoUserId] = OrgMember(
      organizationId: invitation.organizationId,
      userId: FakeOrganizationGateway.demoUserId,
      displayName: 'Demo user',
      locale: 'en',
      role: invitation.role,
      status: MembershipStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return OrgOutcome<String>.success(
      'membership-${invitation.organizationId}',
    );
  }
}
