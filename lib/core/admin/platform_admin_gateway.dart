import '../organizations/organization_models.dart';
import 'audit_entry.dart';

export '../organizations/organization_models.dart';
export 'audit_entry.dart';

/// Platform-owner administration boundary (permission matrix §5).
///
/// The five consumed RPCs (`list_organizations_metadata`,
/// `list_members_metadata`, `suspend_membership_platform`,
/// `reactivate_membership_platform`, `delete_demo_account`) are owner-only:
/// they deny non-owners **server-side** with `permission denied`. The client
/// renders that typed denial distinctly — never empty success (P3.5 AC-7).
///
/// There is deliberately **no client-owned platform-owner claim** (contract
/// §5): the server gates via `is_platform_owner()`, and this seam surfaces
/// the outcome exactly as returned.
///
/// The domain vocabulary is reused from the organization surface: the
/// metadata rows map 1:1 to [OrganizationSummary] (id/name/createdAt) and
/// [OrgMember] (identity + membership metadata), and failures reuse
/// [OrgOutcome]/[OrgFailure] with [OrgFailureKind.denied] as the
/// non-owner signal — no new models or failure kinds exist.
abstract interface class PlatformAdminGateway {
  /// `list_organizations_metadata` — metadata-only cross-org listing
  /// (identity/metadata, never content).
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations();

  /// `list_members_metadata` — metadata-only cross-org membership listing
  /// (identity + membership metadata, never content).
  Future<OrgOutcome<List<OrgMember>>> listMembers();

  /// `suspend_membership_platform(org, user)` — any organization; the
  /// platform boundary (no role changes, no removals, no content).
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  });

  /// `reactivate_membership_platform(org, user)` — any organization.
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  });

  /// `delete_demo_account(user)` — owner-only; the RPC refuses the caller's
  /// own id (never self; self-deletion goes through `delete_my_account`).
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId});

  /// `read_platform_audit()` — owner-only cross-org audit trail (redacted
  /// metadata only; the owner's own read is itself an audited action).
  Future<OrgOutcome<List<AuditEntry>>> readPlatformAudit();

  /// `read_org_audit(org)` — org-scoped audit trail for the selected org
  /// (redacted metadata only).
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  });
}
