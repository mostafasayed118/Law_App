import '../../core/admin/platform_admin_gateway.dart';
import '../orgs/fake_organization_gateway.dart';

/// Development-only platform-admin implementation.
///
/// This class is a seam for presentation tests and env-less runs; it is not
/// an authorization mechanism and must not be used as production authority.
/// It mirrors the signed server semantics (P3.5): the owner-only RPCs gate
/// on `is_platform_owner()` server-side, so this fake gates the demo actor
/// on [demoIsPlatformOwner] — owner → metadata rows; non-owner → the typed
/// [OrgFailureKind.denied], never an empty success (AC-7).
///
/// State derives from the SHARED [FakeOrganizationGateway] instance (the
/// D-P33.2 one-instance DI pattern), so orgs created during an env-less run
/// appear in the admin lists. `deleteDemoAccount` refuses the demo identity,
/// mirroring the RPC's never-self guard (`cannot delete your own account`).
///
/// Known dev-only divergence (documented, not fixed): suspend/reactivate
/// delegate to the org fake, which enforces the last-active-partner guard —
/// `suspend_membership_platform` has no such guard server-side. Stricter
/// than the server is safe for a seam (it never over-grants), but a test
/// pinning "platform may suspend the last partner" would need the real RPC.
class FakePlatformAdminGateway implements PlatformAdminGateway {
  FakePlatformAdminGateway({
    FakeOrganizationGateway? organizationGateway,
    this.demoIsPlatformOwner = true,
  }) : _organizationGateway = organizationGateway ?? FakeOrganizationGateway();

  final FakeOrganizationGateway _organizationGateway;

  /// Mirrors `is_platform_owner()` for the demo actor. Defaults to true so
  /// env-less runs render metadata; tests flip it to pin the AC-7
  /// non-owner-denied path.
  final bool demoIsPlatformOwner;

  @override
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations() async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<OrganizationSummary>>.success(
      _organizationGateway.allOrganizations(),
    );
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers() async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<OrgMember>>.success(
      _organizationGateway.allMembers(),
    );
  }

  @override
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    // Delegate to the shared org fake: any-org semantics, with the
    // last-active-partner guard mirrored from the server.
    return _organizationGateway.suspendMember(
      organizationId: organizationId,
      userId: userId,
    );
  }

  @override
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return _organizationGateway.reactivateMember(
      organizationId: organizationId,
      userId: userId,
    );
  }

  @override
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId}) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (userId == FakeOrganizationGateway.demoUserId) {
      // Mirrors the RPC's never-self refusal; self-deletion goes through
      // `delete_my_account` on the organization surface.
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    _organizationGateway.deleteAccount(userId);
    return const OrgOutcome<void>.success(null);
  }
}
