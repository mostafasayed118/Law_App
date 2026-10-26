part of 'supabase_organization_gateway.dart';

/// The guarded row/failure mapping helpers of
/// [SupabaseOrganizationGateway], library-private top-level functions (they
/// read no instance state, so the class call sites — including the
/// `rows.map(_memberFromRow)` tear-offs — resolve directly).
Future<OrgOutcome<void>> _runVoid(Future<void> Function() call) async {
  try {
    await call();
    return const OrgOutcome<void>.success(null);
  } on SupabaseOrgException catch (e) {
    return OrgOutcome<void>.failure(
      OrgFailure(kind: _mapKind(e.kind), message: orgRequestFailedMessage),
    );
  } on TypeError {
    // Defense-in-depth: no raw TypeError ever crosses the boundary.
    return const OrgOutcome<void>.failure(
      OrgFailure(
        kind: OrgFailureKind.unknown,
        message: orgRequestFailedMessage,
      ),
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

AssignableMember _assignableMemberFromRow(Map<String, dynamic> row) {
  final Object? userId = row['user_id'];
  if (userId is! String || userId.isEmpty) {
    throw FormatException('Assignable member row has no user_id');
  }
  final Object? displayName = row['display_name'];
  if (displayName is! String || displayName.isEmpty) {
    throw FormatException('Assignable member row has no display_name');
  }
  return AssignableMember(userId: userId, displayName: displayName);
}

/// Maps one roster row; an unknown role row is skipped (null) so one
/// provider-drift role cannot fail the whole roster.
OrgMember? _memberFromRow(Map<String, dynamic> row) {
  final UserRole? role = userRoleFromServerName(row['role'] as String?);
  if (role == null) {
    // One unknown role must not fail the whole roster; the row is skipped.
    return null;
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
  // Guarded casts (the _auditEntryFromRow discipline): a missing or
  // wrong-typed organization_id/timestamp is a loud FormatException
  // (caught → unknown), never a raw TypeError crossing the boundary.
  final Object? organizationId = row['organization_id'];
  if (organizationId is! String || organizationId.isEmpty) {
    throw FormatException('Member row has no organization_id');
  }
  final Object? createdAt = row['created_at'];
  final Object? updatedAt = row['updated_at'];
  final DateTime? createdParsed = createdAt is String
      ? DateTime.tryParse(createdAt)
      : null;
  final DateTime? updatedParsed = updatedAt is String
      ? DateTime.tryParse(updatedAt)
      : null;
  if (createdParsed == null || updatedParsed == null) {
    throw FormatException('Member row has unparseable created_at/updated_at');
  }
  return OrgMember(
    organizationId: organizationId,
    userId: identity,
    displayName: (row['display_name'] as String?) ?? identity,
    locale: row['locale'] as String?,
    role: role,
    status: status,
    createdAt: createdParsed.toLocal(),
    updatedAt: updatedParsed.toLocal(),
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
