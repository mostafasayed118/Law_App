/// Provider-neutral platform-admin RPC seam.
///
/// The seam is the only surface [SupabasePlatformAdminGateway] talks to:
/// typed parameters in, plain map rows/scalars out, and typed
/// [SupabasePlatformAdminException]s on failure. Provider exceptions never
/// cross this boundary.
library;

/// Typed reasons a platform-admin RPC call can fail, mapped from the
/// PostgREST surface. The surface is deliberately narrow: the owner-only
/// RPCs either succeed or deny.
enum SupabasePlatformAdminFailureKind {
  /// The caller is not the platform owner (`permission denied`), or the
  /// delete target is the caller themselves (`never self`).
  denied,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabasePlatformAdminApi] seam.
class SupabasePlatformAdminException implements Exception {
  const SupabasePlatformAdminException({
    required this.kind,
    required this.message,
  });

  final SupabasePlatformAdminFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabasePlatformAdminException(${kind.name}): $message';
}

/// Platform-admin RPC surface backed by the Supabase PostgREST client.
abstract interface class SupabasePlatformAdminApi {
  /// `list_organizations_metadata()` rows: `organization_id`, `name`,
  /// `created_at` (metadata only).
  Future<List<Map<String, dynamic>>> listOrganizations();

  /// `list_members_metadata()` rows: `organization_id`, `user_id`,
  /// `display_name`, `locale`, `role`, `status`, `created_at`,
  /// `updated_at` (identity + membership metadata only).
  Future<List<Map<String, dynamic>>> listMembers();

  /// `suspend_membership_platform(p_organization_id, p_user_id)`.
  Future<void> suspendMembership({
    required String organizationId,
    required String userId,
  });

  /// `reactivate_membership_platform(p_organization_id, p_user_id)`.
  Future<void> reactivateMembership({
    required String organizationId,
    required String userId,
  });

  /// `delete_demo_account(p_user_id)` — the RPC refuses `auth.uid()`.
  Future<void> deleteDemoAccount({required String userId});
}
