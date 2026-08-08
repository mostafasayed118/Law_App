import '../../core/admin/platform_admin_gateway.dart';
import '../../core/roles/user_role.dart';
import 'supabase_platform_admin_api.dart';

/// [PlatformAdminGateway] backed by the Supabase provider via
/// [SupabasePlatformAdminApi].
///
/// Domain mapping happens here: raw rows from the seam become the reused
/// [OrganizationSummary]/[OrgMember] metadata models, roles/statuses are
/// validated against the server vocabularies, and typed [OrgFailure]s
/// replace [SupabasePlatformAdminException]s (contract §5 pattern). The
/// non-owner denial crosses as [OrgFailureKind.denied] so presentation can
/// render it distinctly — never as an empty success.
class SupabasePlatformAdminGateway implements PlatformAdminGateway {
  SupabasePlatformAdminGateway(this._api);

  final SupabasePlatformAdminApi _api;

  @override
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listOrganizations();
      return OrgOutcome<List<OrganizationSummary>>.success(
        rows.map(_organizationFromRow).toList(growable: false),
      );
    } on SupabasePlatformAdminException catch (e) {
      return OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    } on FormatException catch (e) {
      // Provider drift (unexpected row shape) surfaces loudly, never as a
      // silently wrong organization.
      return OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: e.message),
      );
    }
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listMembers();
      return OrgOutcome<List<OrgMember>>.success(
        rows.map(_memberFromRow).toList(growable: false),
      );
    } on SupabasePlatformAdminException catch (e) {
      return OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    } on FormatException catch (e) {
      return OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: e.message),
      );
    }
  }

  @override
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  }) => _runVoid(
    () =>
        _api.suspendMembership(organizationId: organizationId, userId: userId),
  );

  @override
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  }) => _runVoid(
    () => _api.reactivateMembership(
      organizationId: organizationId,
      userId: userId,
    ),
  );

  @override
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId}) async {
    if (userId.trim().isEmpty) {
      // Missing input, not a permission denial: honest `unknown` (same
      // convention as the org surface's blank-email guard).
      return const OrgOutcome<void>.failure(
        OrgFailure(
          kind: OrgFailureKind.unknown,
          message: 'User id is required.',
        ),
      );
    }
    return _runVoid(() => _api.deleteDemoAccount(userId: userId.trim()));
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readPlatformAudit() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.readPlatformAudit();
      return OrgOutcome<List<AuditEntry>>.success(
        rows.map(_auditEntryFromRow).toList(growable: false),
      );
    } on SupabasePlatformAdminException catch (e) {
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

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.readOrgAudit(
        organizationId,
      );
      return OrgOutcome<List<AuditEntry>>.success(
        rows.map(_auditEntryFromRow).toList(growable: false),
      );
    } on SupabasePlatformAdminException catch (e) {
      return OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    } on FormatException catch (e) {
      return OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: OrgFailureKind.unknown, message: e.message),
      );
    }
  }

  Future<OrgOutcome<void>> _runVoid(Future<void> Function() call) async {
    try {
      await call();
      return const OrgOutcome<void>.success(null);
    } on SupabasePlatformAdminException catch (e) {
      return OrgOutcome<void>.failure(
        OrgFailure(kind: _mapKind(e.kind), message: e.message),
      );
    }
  }

  OrganizationSummary _organizationFromRow(Map<String, dynamic> row) {
    final String? id = row['organization_id'] as String?;
    final String? name = row['name'] as String?;
    if (id == null || name == null) {
      // Loud, never a silently wrong organization (provider drift).
      throw FormatException('Organization metadata row missing id/name');
    }
    return OrganizationSummary(
      id: id,
      name: name,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  OrgMember _memberFromRow(Map<String, dynamic> row) {
    final String? userId = row['user_id'] as String?;
    if (userId == null) {
      // The platform RPC joins profiles — invited rows (no profile yet) do
      // not appear; a missing id here is provider drift, never silent.
      throw FormatException('Platform member row missing user_id');
    }
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
    return OrgMember(
      organizationId: row['organization_id'] as String,
      userId: userId,
      displayName: (row['display_name'] as String?) ?? userId,
      locale: row['locale'] as String?,
      role: role,
      status: status,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  /// Row → [AuditEntry] mapping. Every cast is guarded: a missing or
  /// wrong-typed column is a [FormatException] (caught → `unknown`), never a
  /// raw [TypeError] crossing the boundary (the documents/messages T7
  /// baseline).
  AuditEntry _auditEntryFromRow(Map<String, dynamic> row) {
    final Object? idValue = row['id'];
    if (idValue is! int) {
      throw FormatException('Audit row id is not an int: $idValue');
    }
    final String? action = _optionalString(row, 'action');
    final String? outcome = _optionalString(row, 'outcome');
    final String? summary = _optionalString(row, 'redacted_summary');
    final String? timestamp = _optionalString(row, 'server_timestamp');
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
      resourceType: _optionalString(row, 'resource_type'),
      resourceId: _optionalString(row, 'resource_id'),
      correlationId: _optionalString(row, 'correlation_id'),
      redactedSummary: summary,
      serverTimestamp: parsed.toLocal(),
      actorUserId: _optionalString(row, 'actor_user_id'),
      organizationId: _optionalString(row, 'organization_id'),
    );
  }

  /// Null → null; a String → itself; any other non-null value is provider
  /// drift and surfaces loudly as a [FormatException] — never a raw
  /// [TypeError] crossing the boundary (the documents/messages T7 baseline).
  String? _optionalString(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('Audit row $key is not a string: $value');
  }

  OrgFailureKind _mapKind(SupabasePlatformAdminFailureKind kind) {
    return switch (kind) {
      SupabasePlatformAdminFailureKind.denied => OrgFailureKind.denied,
      SupabasePlatformAdminFailureKind.providerUnavailable =>
        OrgFailureKind.providerUnavailable,
      SupabasePlatformAdminFailureKind.unknown => OrgFailureKind.unknown,
    };
  }
}
