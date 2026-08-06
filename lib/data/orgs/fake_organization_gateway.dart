import '../../core/auth/session.dart';
import '../../core/organizations/organization_gateway.dart';
import '../../core/roles/user_role.dart';

/// Development-only organization implementation.
///
/// This class is a seam for presentation tests and env-less runs; it is not
/// an authorization mechanism and must not be used as production authority.
/// It mirrors the signed server semantics so the UI behaves like the real
/// surface: org creation makes the actor its initial partner, invites reject
/// existing members, role changes/suspensions/removals enforce the
/// last-active-partner guard, and invitations carry ids so Resend/Revoke
/// target the pending row exactly like `resend_invitation` /
/// `revoke_invitation` do server-side.
class FakeOrganizationGateway implements OrganizationGateway {
  FakeOrganizationGateway() {
    _orgs.addAll(<String, OrganizationSummary>{
      demoOrganizationId: OrganizationSummary(
        id: demoOrganizationId,
        name: 'Demo Firm',
        createdAt: _seedTime,
      ),
    });
    _members.addAll(<String, Map<String, OrgMember>>{
      demoOrganizationId: <String, OrgMember>{
        demoUserId: OrgMember(
          organizationId: demoOrganizationId,
          userId: demoUserId,
          displayName: 'Demo user',
          locale: 'en',
          role: UserRole.partner,
          status: MembershipStatus.active,
          createdAt: _seedTime,
          updatedAt: _seedTime,
        ),
      },
    });
  }

  /// The demo identity shared with the fake auth session.
  static const String demoUserId = 'demo-user';
  static const String demoOrganizationId = 'org-demo';

  /// The demo identity's email, mirroring the fake auth session's claim (the
  /// server matches `accept_invitation` against the JWT email claim).
  static const String demoUserEmail = 'demo@firm.com';

  static final DateTime _seedTime = DateTime.utc(2026, 7, 25);

  final Map<String, OrganizationSummary> _orgs =
      <String, OrganizationSummary>{};
  final Map<String, Map<String, OrgMember>> _members =
      <String, Map<String, OrgMember>>{};

  final Map<String, _FakeInvitation> _invitations = <String, _FakeInvitation>{};
  int _inviteCounter = 0;

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const OrgOutcome<OrganizationSummary>.failure(
        OrgFailure(kind: OrgFailureKind.invalidName),
      );
    }
    final String id = 'org-${_orgs.length + 1}';
    final OrganizationSummary summary = OrganizationSummary(
      id: id,
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _orgs[id] = summary;
    _members[id] = <String, OrgMember>{
      demoUserId: OrgMember(
        organizationId: id,
        userId: demoUserId,
        displayName: 'Demo user',
        locale: 'en',
        role: UserRole.partner,
        status: MembershipStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    };
    return OrgOutcome<OrganizationSummary>.success(summary);
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) async {
    final Map<String, OrgMember>? roster = _members[organizationId];
    if (roster == null) {
      return const OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<OrgMember>>.success(
      roster.values.toList(growable: false),
    );
  }

  @override
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

  @override
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) async {
    final String? roleName = _assignableRoleName(role);
    if (roleName == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.invalidRole),
      );
    }
    final Map<String, OrgMember>? roster = _members[organizationId];
    if (roster == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    final OrgMember? target = roster[userId];
    if (target == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (target.role == UserRole.partner &&
        role != UserRole.partner &&
        !_anotherActivePartnerExists(roster, userId)) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.lastPartner),
      );
    }
    roster[userId] = _copy(target, role: role);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) async {
    final Map<String, OrgMember>? roster = _members[organizationId];
    final OrgMember? target = roster?[userId];
    if (roster == null || target == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (target.role == UserRole.partner &&
        !_anotherActivePartnerExists(roster, userId)) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.lastPartner),
      );
    }
    roster[userId] = _copy(target, status: MembershipStatus.suspended);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {
    final Map<String, OrgMember>? roster = _members[organizationId];
    final OrgMember? target = roster?[userId];
    if (roster == null || target == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    roster[userId] = _copy(target, status: MembershipStatus.active);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    final Map<String, OrgMember>? roster = _members[organizationId];
    final OrgMember? target = roster?[userId];
    if (roster == null || target == null) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (userId == demoUserId) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (target.role == UserRole.partner &&
        !_anotherActivePartnerExists(roster, userId)) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.lastPartner),
      );
    }
    roster[userId] = _copy(target, status: MembershipStatus.removed);
    return const OrgOutcome<void>.success(null);
  }

  @override
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

  @override
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

  @override
  Future<OrgOutcome<void>> deleteMyAccount() async {
    // Mirrors the server cascade: profiles/memberships of the caller vanish;
    // organizations keep their rows with created_by/actor cleared (the fake
    // has no cross-entity actor columns beyond the demo identity).
    for (final Map<String, OrgMember> roster in _members.values) {
      roster.remove(demoUserId);
    }
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<String>> acceptInvitation({required String token}) async {
    final _FakeInvitation? invitation = _invitations.values
        .where(
          (_FakeInvitation inv) =>
              inv.status == _FakeInvitationStatus.pending && inv.token == token,
        )
        .firstOrNull;
    // Mirrors the server's undifferentiated denial: unknown/expired tokens
    // and email mismatches all read as "invalid invitation".
    if (invitation == null || invitation.email != demoUserEmail.toLowerCase()) {
      return const OrgOutcome<String>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );
    }
    invitation.status = _FakeInvitationStatus.accepted;
    final Map<String, OrgMember> roster = _members[invitation.organizationId]!;
    // The pending invited row (keyed by email) becomes the real membership
    // with the SERVER-OWNED role from the invitation.
    roster.remove(invitation.email);
    roster[demoUserId] = OrgMember(
      organizationId: invitation.organizationId,
      userId: demoUserId,
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
      final OrgMember? me = entry.value[demoUserId];
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

  bool _anotherActivePartnerExists(
    Map<String, OrgMember> roster,
    String userId,
  ) {
    for (final OrgMember member in roster.values) {
      if (member.userId != userId &&
          member.role == UserRole.partner &&
          member.isActive) {
        return true;
      }
    }
    return false;
  }

  String? _assignableRoleName(UserRole role) {
    return switch (role) {
      UserRole.client => 'client',
      UserRole.attorney => 'attorney',
      UserRole.partner => 'partner',
      _ => null,
    };
  }

  OrgMember _copy(
    OrgMember source, {
    UserRole? role,
    MembershipStatus? status,
  }) => OrgMember(
    organizationId: source.organizationId,
    userId: source.userId,
    displayName: source.displayName,
    locale: source.locale,
    role: role ?? source.role,
    status: status ?? source.status,
    createdAt: source.createdAt,
    updatedAt: DateTime.now(),
    invitationId: source.invitationId,
  );
}

enum _FakeInvitationStatus { pending, revoked, accepted }

/// A pending invitation mirror: the literal token is kept for demo
/// continuity (the real surface stores only the sha-256 hash — nothing
/// leaves the process, so the literal is safe here).
class _FakeInvitation {
  _FakeInvitation({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.status,
    required this.token,
  });

  final String id;
  final String organizationId;
  final String email;
  final UserRole role;
  _FakeInvitationStatus status;
  String token;
}
