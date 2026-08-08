import '../../core/organizations/organization_gateway.dart';
import '../../core/roles/user_role.dart';
import 'supabase_org_api.dart';

/// [OrganizationGateway] backed by the Supabase provider via [SupabaseOrgApi].
///
/// Domain mapping happens here: raw rows/scalars from the seam become
/// [OrgMember]/[OrganizationSummary]/[InviteResult], roles are validated
/// against the server-assignable surface before any call, and typed
/// [OrgFailure]s replace [SupabaseOrgException]s (contract §5 pattern).
class SupabaseOrganizationGateway implements OrganizationGateway {
  SupabaseOrganizationGateway(this._api);

  final SupabaseOrgApi _api;

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async {
    if (name.trim().isEmpty) {
      return const OrgOutcome<OrganizationSummary>.failure(
        OrgFailure(kind: OrgFailureKind.invalidName),
      );
    }
    try {
      final String id = await _api.createOrganization(name: name.trim());
      return OrgOutcome<OrganizationSummary>.success(
        OrganizationSummary(
          id: id,
          name: name.trim(),
          createdAt: DateTime.now(),
        ),
      );
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<OrganizationSummary>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listMembers(
        organizationId: organizationId,
      );
      return OrgOutcome<List<OrgMember>>.success(
        rows.map(_memberFromRow).toList(growable: false),
      );
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    } on FormatException catch (e) {
      // Provider drift (unexpected role/status name) surfaces loudly, never
      // as a silently wrong member.
      return OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: e.message),
      );
    }
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
    if (email.trim().isEmpty) {
      return const OrgOutcome<InviteResult>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: 'Email is required.'),
      );
    }
    try {
      final String token = await _api.inviteMember(
        organizationId: organizationId,
        email: email.trim(),
        role: roleName,
      );
      return OrgOutcome<InviteResult>.success(
        InviteResult(
          organizationId: organizationId,
          email: email.trim(),
          token: token,
        ),
      );
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<InviteResult>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
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
    return _runVoid(
      () => _api.changeMemberRole(
        organizationId: organizationId,
        userId: userId,
        role: roleName,
      ),
    );
  }

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) => _runVoid(
    () => _api.suspendMember(organizationId: organizationId, userId: userId),
  );

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) => _runVoid(
    () => _api.reactivateMember(organizationId: organizationId, userId: userId),
  );

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) => _runVoid(
    () => _api.removeMember(organizationId: organizationId, userId: userId),
  );

  @override
  Future<OrgOutcome<String>> resendInvitation({
    required String invitationId,
  }) async {
    try {
      final String token = await _api.resendInvitation(
        invitationId: invitationId,
      );
      return OrgOutcome<String>.success(token);
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<String>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
  }

  @override
  Future<OrgOutcome<void>> revokeInvitation({required String invitationId}) =>
      _runVoid(() => _api.revokeInvitation(invitationId: invitationId));

  @override
  Future<OrgOutcome<void>> deleteMyAccount() =>
      _runVoid(() => _api.deleteMyAccount());

  @override
  Future<OrgOutcome<String>> acceptInvitation({required String token}) async {
    if (token.trim().isEmpty) {
      return const OrgOutcome<String>.failure(
        OrgFailure(kind: OrgFailureKind.invalidInvitation),
      );
    }
    try {
      final String membershipId = await _api.acceptInvitation(
        token: token.trim(),
      );
      return OrgOutcome<String>.success(membershipId);
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<String>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.readOrgAudit(
        organizationId: organizationId,
      );
      return OrgOutcome<List<AuditEntry>>.success(
        rows.map(_auditEntryFromRow).toList(growable: false),
      );
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    } on FormatException catch (e) {
      // Provider drift (unexpected row shape) surfaces loudly, never as a
      // silently wrong audit entry.
      return OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: e.message),
      );
    }
  }

  Future<OrgOutcome<void>> _runVoid(Future<void> Function() call) async {
    try {
      await call();
      return const OrgOutcome<void>.success(null);
    } on SupabaseOrgException catch (e) {
      return OrgOutcome<void>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
  }

  /// Only the three server-assignable roles may leave the boundary; anything
  /// else is rejected with [OrgFailureKind.invalidRole] (loud, never a
  /// silently wrong role on the server).
  String? _assignableRoleName(UserRole role) {
    return switch (role) {
      UserRole.client => 'client',
      UserRole.attorney => 'attorney',
      UserRole.partner => 'partner',
      _ => null,
    };
  }

  OrgMember _memberFromRow(Map<String, dynamic> row) {
    final UserRole? role = userRoleFromServerName(row['role'] as String?);
    if (role == null) {
      throw FormatException('Unknown server role name: ${row['role']}');
    }
    final MembershipStatus? status = membershipStatusFromServerName(
      row['status'] as String?,
    );
    if (status == null) {
      throw FormatException('Unknown server status name: ${row['status']}');
    }
    // R1 invited rows carry no user id yet (RPC §3): the invited address is
    // the roster identity until the invite is accepted — the same
    // `userId = email` convention the fake uses (design §8 reconciliation).
    final String? userId = row['user_id'] as String?;
    final String? email = row['email'] as String?;
    if (userId == null && email == null) {
      // Loud, never a silently empty roster identity (provider drift).
      throw FormatException('Member row has neither user_id nor email');
    }
    final String identity = userId ?? email!;
    return OrgMember(
      organizationId: row['organization_id'] as String,
      userId: identity,
      displayName: (row['display_name'] as String?) ?? identity,
      locale: row['locale'] as String?,
      role: role,
      status: status,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      // The member-facing surface exposes the invitation id for invited
      // rows (R1), so Resend/Revoke target a real id; member rows stay null.
      invitationId: row['invitation_id'] as String?,
    );
  }

  /// Row → [AuditEntry] mapping (mirrors the platform-admin seam's guarded
  /// cast discipline): a missing or wrong-typed column is a [FormatException]
  /// (caught → `unknown`), never a raw [TypeError] crossing the boundary.
  AuditEntry _auditEntryFromRow(Map<String, dynamic> row) {
    final Object? idValue = row['id'];
    if (idValue is! int) {
      throw FormatException('Audit row id is not an int: $idValue');
    }
    final String? action = row['action'] as String?;
    final String? outcome = row['outcome'] as String?;
    final String? summary = row['redacted_summary'] as String?;
    final String? timestamp = row['server_timestamp'] as String?;
    if (action == null ||
        outcome == null ||
        summary == null ||
        timestamp == null) {
      throw FormatException(
        'Audit row missing action/outcome/redacted_summary/server_timestamp',
      );
    }
    final DateTime? parsed = DateTime.tryParse(timestamp);
    if (parsed == null) {
      throw FormatException('Audit row server_timestamp unparseable');
    }
    return AuditEntry(
      id: idValue,
      action: action,
      outcome: outcome,
      resourceType: row['resource_type'] as String?,
      resourceId: row['resource_id'] as String?,
      correlationId: row['correlation_id'] as String?,
      redactedSummary: summary,
      serverTimestamp: parsed,
      // Org variant: the RPC returns no actor/org columns (the platform
      // variant adds them) — both stay null here.
    );
  }

  OrgFailureKind _mapKind(SupabaseOrgFailureKind kind) {
    return switch (kind) {
      SupabaseOrgFailureKind.denied => OrgFailureKind.denied,
      SupabaseOrgFailureKind.duplicateMember => OrgFailureKind.duplicateMember,
      SupabaseOrgFailureKind.lastPartner => OrgFailureKind.lastPartner,
      SupabaseOrgFailureKind.invalidName => OrgFailureKind.invalidName,
      SupabaseOrgFailureKind.invalidInvitation =>
        OrgFailureKind.invalidInvitation,
      SupabaseOrgFailureKind.providerUnavailable =>
        OrgFailureKind.providerUnavailable,
      SupabaseOrgFailureKind.unknown => OrgFailureKind.unknown,
    };
  }
}
