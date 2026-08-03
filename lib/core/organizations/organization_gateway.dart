import '../roles/user_role.dart';
import 'organization_models.dart';

export 'organization_models.dart';

/// Organization and membership integration boundary.
///
/// The domain boundary returns application models via [OrgOutcome] — never
/// raw Supabase DTOs, tokens, or provider exceptions. The server remains the
/// authority: roles and statuses arrive from the RPC surface, and the client
/// never invents capabilities. Bootstrap has no provider implementation; the
/// dev fake is the synthetic seam used by presentation and tests.
abstract interface class OrganizationGateway {
  /// Creates an organization and makes the caller its initial partner
  /// (server-side D-08: client supplies only the name).
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  });

  /// Lists the members of one organization (identity + membership metadata
  /// only). The caller must be an active member of the organization.
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  });

  /// Invites an email to an organization. Only [serverAssignableRoles] may be
  /// requested; the one-time token is returned for out-of-band delivery.
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  });

  /// Changes a member's role. The organization must retain at least one
  /// active partner (server-enforced last-partner guard).
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  });

  /// Suspends a member. The organization must retain at least one active
  /// partner (server-enforced last-partner guard).
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  });

  /// Reactivates a suspended member.
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  });

  /// Removes a member (status `removed`). Self-removal is denied server-side
  /// (use account deletion).
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  });

  /// Rotates a PENDING invite's one-time token (`resend_invitation`). The
  /// fresh token is returned for out-of-band delivery; only its sha-256 hash
  /// is stored. Unknown or non-pending invitation ids fail with
  /// [OrgFailureKind.invalidInvitation].
  Future<OrgOutcome<String>> resendInvitation({required String invitationId});

  /// Revokes a PENDING invite (`revoke_invitation`) — status transition, the
  /// audit trail survives; the invited row leaves the pending roster.
  /// Unknown or non-pending invitation ids fail with
  /// [OrgFailureKind.invalidInvitation].
  Future<OrgOutcome<void>> revokeInvitation({required String invitationId});

  /// Hard-deletes the caller's identity (`delete_my_account`, D-05 — the
  /// only removal path; no direct DELETE policy exists). Memberships cascade;
  /// audit rows survive with the actor reference cleared.
  Future<OrgOutcome<void>> deleteMyAccount();

  /// Redeems a one-time invitation token (`accept_invitation`) — the role is
  /// server-owned from the invitation; the client never chooses one. Returns
  /// the new membership id.
  Future<OrgOutcome<String>> acceptInvitation({required String token});
}
