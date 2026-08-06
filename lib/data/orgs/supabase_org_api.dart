/// Provider-neutral organization RPC seam.
///
/// The seam is the only surface the organization gateway talks to: typed
/// parameters in, plain maps/scalars out, typed [SupabaseOrgException]s on
/// failure. Provider exceptions never cross this boundary.
library;

/// Typed reasons an RPC call can fail, mapped from the PostgREST surface.
enum SupabaseOrgFailureKind {
  /// The caller is not permitted (permission denied / self-removal).
  denied,

  /// The invite target already has a membership in the organization.
  duplicateMember,

  /// The operation would leave the organization without an active partner.
  lastPartner,

  /// The organization name was rejected.
  invalidName,

  /// The invitation token is wrong, expired, or foreign.
  invalidInvitation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseOrgApi] seam.
class SupabaseOrgException implements Exception {
  const SupabaseOrgException({required this.kind, required this.message});

  final SupabaseOrgFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseOrgException(${kind.name}): $message';
}

/// Organization RPC surface backed by the Supabase PostgREST client.
abstract interface class SupabaseOrgApi {
  /// `create_organization(p_name)` — returns the new organization id.
  Future<String> createOrganization({required String name});

  /// `list_org_members_metadata(p_organization_id)` rows for ONE
  /// organization (Phase 3 R1, applied): partner-scoped member roster with
  /// identity metadata + pending invitations (invited rows carry
  /// `invitation_id` + `email` with a NULL `user_id`). Returns raw map rows
  /// (identity + membership metadata).
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  });

  /// RLS-scoped SELECT of the caller's own `memberships` rows, embedded with
  /// the joined `organizations` name (P3.2 membership hydration).
  ///
  /// The memberships policy returns the caller's own rows (own-row OR
  /// active-member); the `organizations` policy is active-member-only, so
  /// `organizationName` resolves for active memberships and is NULL for
  /// suspended/removed ones (their org row is not visible). Returns raw map
  /// rows: `organization_id`, `role`, `status`, and a nested
  /// `organizations: {'name': …}` map (or null).
  Future<List<Map<String, dynamic>>> listMyMemberships();

  /// `invite_member(org, email, role)` — returns the one-time token.
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  });

  /// `change_member_role(org, user, role)`.
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  });

  /// `suspend_membership(org, user)`.
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  });

  /// `reactivate_membership(org, user)`.
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  });

  /// `remove_membership(org, user)`.
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  });

  /// `resend_invitation(p_invitation_id)` — rotates a PENDING invite's token
  /// and returns the new one-time token (only its hash is stored).
  Future<String> resendInvitation({required String invitationId});

  /// `revoke_invitation(p_invitation_id)` — status-transitions a PENDING
  /// invite to revoked (never a DELETE; the audit trail survives).
  Future<void> revokeInvitation({required String invitationId});

  /// `delete_my_account()` — hard-deletes the caller's identity (D-05; the
  /// only removal path). Audit rows survive with the actor reference cleared.
  Future<void> deleteMyAccount();

  /// `accept_invitation(p_token)` — redeems a one-time token; the role is
  /// server-owned from the invitation. Returns the new membership id.
  Future<String> acceptInvitation({required String token});
}
