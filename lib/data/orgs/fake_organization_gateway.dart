import '../../core/auth/session.dart';
import '../../core/organizations/organization_gateway.dart';
import '../../core/roles/user_role.dart';
part 'fake_organization_state.dart';
part 'fake_organization_invitations.dart';
part 'fake_organization_admin.dart';
part 'fake_organization_demo.dart';
part 'fake_organization_helpers.dart';
part 'fake_organization_support.dart';

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
class FakeOrganizationGateway extends _FakeOrgState
    with _FakeOrgInvitations, _FakeOrgAdmin, _FakeOrgDemo
    implements OrganizationGateway {
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
    _audit.addAll(<String, List<AuditEntry>>{
      demoOrganizationId: demoAuditEntries(),
    });
  }

  /// The demo identity shared with the fake auth session.
  static const String demoUserId = 'demo-user';
  static const String demoOrganizationId = 'org-demo';

  /// The demo identity's email, mirroring the fake auth session's claim (the
  /// server matches `accept_invitation` against the JWT email claim).
  static const String demoUserEmail = 'demo@firm.com';

  static final DateTime _seedTime = DateTime.utc(2026, 7, 25);

  /// Deterministic, non-PII demo audit trail for the demo org — mirrors the
  /// org-scoped RPC's redacted rows (action/outcome/redacted summary/
  /// correlation id/timestamp only; no content, no credentials, no real
  /// identity).
  static List<AuditEntry> demoAuditEntries() => <AuditEntry>[
    AuditEntry(
      id: 1,
      action: 'member:role/change',
      outcome: 'allowed',
      resourceType: 'membership',
      resourceId: 'demo-user',
      correlationId: 'audit-org-demo-1',
      redactedSummary: 'role change',
      serverTimestamp: DateTime.utc(2026, 7, 25, 10, 0),
    ),
    AuditEntry(
      id: 2,
      action: 'member:invite',
      outcome: 'allowed',
      resourceType: 'invitation',
      resourceId: 'inv-demo-1',
      correlationId: 'audit-org-demo-2',
      redactedSummary: 'invitation sent',
      serverTimestamp: DateTime.utc(2026, 7, 25, 11, 30),
    ),
    AuditEntry(
      id: 3,
      action: 'member:suspend',
      outcome: 'denied',
      resourceType: 'membership',
      resourceId: 'unknown-user',
      correlationId: 'audit-org-demo-3',
      redactedSummary: 'suspension denied',
      serverTimestamp: DateTime.utc(2026, 7, 25, 12, 45),
    ),
  ];

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
}
