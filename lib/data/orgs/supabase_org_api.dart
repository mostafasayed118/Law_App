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

  /// `list_members_metadata` rows for one organization. NOTE: the RPC is
  /// platform-owner-only; the member-facing member list surface is a P3
  /// follow-up. Returns raw map rows (identity + membership metadata).
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  });

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
