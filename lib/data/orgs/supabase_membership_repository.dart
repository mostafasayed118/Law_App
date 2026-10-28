import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/observability/app_log.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/organizations/organization_models.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'supabase_org_api.dart';

/// [MembershipRepository] backed by the RLS-scoped SELECT surface
/// ([SupabaseOrgApi.listMyMemberships]).
///
/// Row → [OrganizationMembership] mapping happens here, strictly below the
/// domain seam: rows not owned by the caller's `user_id` are dropped (the
/// memberships policy also admits active co-members), role/status go through
/// the existing server-name mappers (D-T5), unknown schema roles/statuses are
/// **dropped loudly** (D-P32.1 — never projected as a capability the client
/// does not understand), and a null org name (suspended/removed membership)
/// is tolerated per the plan §6 name-resolution note. No DTOs or tokens cross
/// this boundary.
///
/// A provider read failure is a typed [HydrationFailed] (never a fabricated
/// membership, never a session invalidation) so the cubit seam can surface
/// offline/denied through the diagnostic channel (Task 8 review input 1).
class SupabaseMembershipRepository implements MembershipRepository {
  SupabaseMembershipRepository(this._api);

  final SupabaseOrgApi _api;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listMyMemberships(
        userId: userId,
      );
      final List<OrganizationMembership> memberships =
          <OrganizationMembership>[];
      for (final Map<String, dynamic> row in rows) {
        // Own-membership only: the RLS policy also exposes active
        // co-members' rows, so a foreign row must never be mapped into this
        // session (another member's role is not the caller's role).
        if (row['user_id'] != userId) {
          AppLog.diagnostic(
            'membership hydration: dropping a row for a different user',
          );
          continue;
        }
        final OrganizationMembership? membership = _fromRow(row);
        if (membership != null) {
          memberships.add(membership);
        }
      }
      return HydrationSucceeded(memberships);
    } on SupabaseOrgException catch (e) {
      return HydrationFailed(_mapFailureKind(e.kind));
    } on Exception {
      // R6 (2026-09-24): a transport failure (timeout/offline/closed client)
      // is a typed unavailable, never a raw exception across the seam (the
      // matter/document/message api impls' defensive-catch precedent). The
      // cubit treats it as best-effort enrichment, so the session is never
      // invalidated by a network blip.
      return const HydrationFailed(
        MembershipHydrationFailureKind.providerUnavailable,
      );
    }
  }

  /// Maps the provider seam's failure vocabulary to the hydration outcome.
  /// RPC-only kinds (duplicateMember/lastPartner/invalidName/
  /// invalidInvitation) cannot occur on the memberships SELECT and fall
  /// through to [MembershipHydrationFailureKind.unknown].
  MembershipHydrationFailureKind _mapFailureKind(SupabaseOrgFailureKind kind) =>
      switch (kind) {
        SupabaseOrgFailureKind.denied => MembershipHydrationFailureKind.denied,
        SupabaseOrgFailureKind.providerUnavailable =>
          MembershipHydrationFailureKind.providerUnavailable,
        _ => MembershipHydrationFailureKind.unknown,
      };

  /// Maps one raw membership row, or null when the row cannot be projected
  /// safely (unknown role/status per D-P32.1, a non-string role/status, or a
  /// missing organization id).
  OrganizationMembership? _fromRow(Map<String, dynamic> row) {
    // Provider drift must be dropped, not thrown. A `row['role'] as String?`
    // cast on a non-string raises a `TypeError` — an `Error`, not an
    // `Exception` — so it used to slip past [loadMemberships]' exception
    // catches and strand sign-in with a raw async error (audit 2026-10-27,
    // F13). Type-check first; a non-string is dropped like an unknown value.
    final Object? roleValue = row['role'];
    if (roleValue is! String) {
      AppLog.diagnostic('membership hydration: dropping a non-string role');
      return null;
    }
    final UserRole? role = userRoleFromServerName(roleValue);
    if (role == null) {
      // D-P32.1: unknown schema role → drop loudly, never project a
      // capability hint for a role the client does not understand.
      AppLog.diagnostic(
        'membership hydration: dropping row with unknown role "$roleValue"',
      );
      return null;
    }
    final Object? statusValue = row['status'];
    if (statusValue is! String) {
      AppLog.diagnostic('membership hydration: dropping a non-string status');
      return null;
    }
    final MembershipStatus? status = membershipStatusFromServerName(
      statusValue,
    );
    if (status == null) {
      AppLog.diagnostic(
        'membership hydration: dropping row with unknown status "$statusValue"',
      );
      return null;
    }
    final Object? organizationId = row['organization_id'];
    if (organizationId is! String || organizationId.isEmpty) {
      AppLog.diagnostic(
        'membership hydration: dropping row without organization id',
      );
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
