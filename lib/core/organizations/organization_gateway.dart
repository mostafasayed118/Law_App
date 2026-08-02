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
}
