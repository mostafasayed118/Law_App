import '../../core/organizations/organization_gateway.dart';
import '../../core/roles/user_role.dart';

/// Development-only organization implementation.
///
/// This class is a seam for presentation tests and env-less runs; it is not
/// an authorization mechanism and must not be used as production authority.
/// It mirrors the signed server semantics so the UI behaves like the real
/// surface: org creation makes the actor its initial partner, invites reject
/// existing members, and role changes/suspensions/removals enforce the
/// last-active-partner guard.
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

  static final DateTime _seedTime = DateTime.utc(2026, 7, 25);

  final Map<String, OrganizationSummary> _orgs =
      <String, OrganizationSummary>{};
  final Map<String, Map<String, OrgMember>> _members =
      <String, Map<String, OrgMember>>{};

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
    roster[key] = OrgMember(
      organizationId: organizationId,
      userId: key,
      displayName: key,
      locale: null,
      role: role,
      status: MembershipStatus.invited,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return OrgOutcome<InviteResult>.success(
      InviteResult(
        organizationId: organizationId,
        email: email.trim(),
        token: 'demo-invite-token-${roster.length}',
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
  );
}
