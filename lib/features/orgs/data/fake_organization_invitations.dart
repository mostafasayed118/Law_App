part of 'fake_organization_gateway.dart';

/// The invitation lifecycle group of [FakeOrganizationGateway] — the same
/// method bodies moved verbatim; the class applies this mixin so the
/// [OrganizationGateway] interface stays satisfied.
mixin _FakeOrgInvitations on _FakeOrgState {
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  }) async {
    final String? roleName = _assignableRoleName(role);
    if (roleName == null) {
      return const OrgOutcome<InviteResult>.failure(
        OrgFailure(kind: OrgFailureKind.invalidRole),
      );
    }
    final Map<String, OrgMember>? roster = _members[organizationId];
    if (roster == null) {
      return const OrgOutcome<InviteResult>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    final String key = email.trim().toLowerCase();
    final bool exists = roster.values.any(
      (OrgMember member) =>
          member.userId == key || member.displayName.toLowerCase() == key,
    );
    if (exists) {
      return const OrgOutcome<InviteResult>.failure(
        OrgFailure(kind: OrgFailureKind.duplicateMember),
      );
    }
    // Mirrors the server's membership rows for invited identities (the real
    // surface stores the sha-256 hash only — the fake keeps the literal for
    // demo continuity, which is fine because nothing leaves the process).
    final String token = 'demo-invite-token-${roster.length}';
    final String invitationId = 'inv-${++_inviteCounter}';
    _invitations[invitationId] = _FakeInvitation(
      id: invitationId,
      organizationId: organizationId,
      email: key,
      role: role,
      status: _FakeInvitationStatus.pending,
      token: token,
    );
    roster[key] = OrgMember(
      organizationId: organizationId,
      userId: key,
      displayName: key,
      locale: null,
      role: role,
      status: MembershipStatus.invited,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      invitationId: invitationId,
    );
    return OrgOutcome<InviteResult>.success(
      InviteResult(
        organizationId: organizationId,
        email: email.trim(),
        token: token,
      ),
    );
  }

  Future<OrgOutcome<String>> resendInvitation({
    required String invitationId,
  }) async {
    final _FakeInvitation? invitation = _invitations[invitationId];
    if (invitation == null ||
        invitation.status != _FakeInvitationStatus.pending) {
      return const OrgOutcome<String>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );
    }
    final String token = 'demo-invite-token-resend-${++_inviteCounter}';
    invitation.token = token;
    return OrgOutcome<String>.success(token);
  }

  Future<OrgOutcome<void>> revokeInvitation({
    required String invitationId,
  }) async {
    final _FakeInvitation? invitation = _invitations[invitationId];
    if (invitation == null ||
        invitation.status != _FakeInvitationStatus.pending) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );
    }
    invitation.status = _FakeInvitationStatus.revoked;
    // A revoked invite is no longer pending: the invited row leaves the
    // roster on the next read (revocation is a status transition, never a
    // DELETE — the fake's registry is the surviving audit trail).
    _members[invitation.organizationId]?.remove(invitation.email);
    return const OrgOutcome<void>.success(null);
  }
}
