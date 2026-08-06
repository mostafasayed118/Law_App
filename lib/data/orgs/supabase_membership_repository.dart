import 'package:flutter/foundation.dart';

import '../../core/auth/session.dart';
import '../../core/organizations/membership_repository.dart';
import '../../core/organizations/organization_models.dart';
import '../../core/roles/user_role.dart';
import 'supabase_org_api.dart';

/// [MembershipRepository] backed by the RLS-scoped SELECT surface
/// ([SupabaseOrgApi.listMyMemberships]).
///
/// Row → [OrganizationMembership] mapping happens here, strictly below the
/// domain seam: role/status go through the existing server-name mappers
/// (D-T5), unknown schema roles/statuses are **dropped loudly** (D-P32.1 —
/// never projected as a capability the client does not understand), and a
/// null org name (suspended/removed membership) is tolerated per the plan
/// §6 name-resolution note. No DTOs or tokens cross this boundary.
class SupabaseMembershipRepository implements MembershipRepository {
  SupabaseMembershipRepository(this._api);

  final SupabaseOrgApi _api;

  @override
  Future<List<OrganizationMembership>> loadMemberships({
    required String userId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listMyMemberships();
      final List<OrganizationMembership> memberships =
          <OrganizationMembership>[];
      for (final Map<String, dynamic> row in rows) {
        final OrganizationMembership? membership = _fromRow(row);
        if (membership != null) {
          memberships.add(membership);
        }
      }
      return memberships;
    } on SupabaseOrgException catch (e) {
      // Hydration is best-effort enrichment of an already-authenticated
      // session (contract §5): a read failure resolves to the honest empty
      // list, never a fabricated membership and never a session
      // invalidation. Loud for diagnostics; the screen surfaces offline/
      // retry independently.
      debugPrint('membership hydration failed: ${e.kind.name}: ${e.message}');
      return const <OrganizationMembership>[];
    }
  }

  /// Maps one raw membership row, or null when the row cannot be projected
  /// safely (unknown role/status per D-P32.1, or a missing organization id).
  OrganizationMembership? _fromRow(Map<String, dynamic> row) {
    final UserRole? role = userRoleFromServerName(row['role'] as String?);
    if (role == null) {
      // D-P32.1: unknown schema role → drop loudly, never project a
      // capability hint for a role the client does not understand.
      debugPrint(
        'membership hydration: dropping row with unknown role '
        '${row['role']}',
      );
      return null;
    }
    final MembershipStatus? status = membershipStatusFromServerName(
      row['status'] as String?,
    );
    if (status == null) {
      debugPrint(
        'membership hydration: dropping row with unknown status '
        '${row['status']}',
      );
      return null;
    }
    final Object? organizationId = row['organization_id'];
    if (organizationId is! String || organizationId.isEmpty) {
      debugPrint('membership hydration: dropping row without organization id');
      return null;
    }
    // The embedded organizations(name) join is null for suspended/removed
    // memberships (their org row is not visible) — tolerated per plan §6.
    final Object? organizations = row['organizations'];
    final String? organizationName = organizations is Map<String, dynamic>
        ? organizations['name'] as String?
        : null;
    return OrganizationMembership(
      organizationId: organizationId,
      organizationName: organizationName,
      role: role,
      status: status,
    );
  }
}
