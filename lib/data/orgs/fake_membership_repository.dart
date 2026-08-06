import '../../core/auth/session.dart';
import '../../core/organizations/membership_repository.dart';
import '../../core/roles/user_role.dart';

/// Development-only membership hydration implementation.
///
/// Mirrors the demo session's membership (`FakeAuthGateway.demoMembership`:
/// org-demo / Demo Firm / partner / active) so env-less runs and tests
/// hydrate the same memberships the demo session carries. This is a seam for
/// presentation tests and env-less runs — it is not an authorization
/// mechanism and must not be used as production authority.
class FakeMembershipRepository implements MembershipRepository {
  /// The demo active membership, shared with the fake auth session.
  ///
  /// Role is **partner** — reconciled (P3.2 Task 8) with
  /// `FakeOrganizationGateway`'s roster seed, which makes the demo user the
  /// org creator (initial partner), so the hub capability surface agrees
  /// with the session.
  static const OrganizationMembership demoMembership = OrganizationMembership(
    organizationId: 'org-demo',
    organizationName: 'Demo Firm',
    role: UserRole.partner,
    status: MembershipStatus.active,
  );

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    return const HydrationSucceeded(<OrganizationMembership>[demoMembership]);
  }
}
