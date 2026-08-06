import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';

void main() {
  group('FakeMembershipRepository', () {
    test('hydrates the demo active membership for any caller', () async {
      final FakeMembershipRepository repository = FakeMembershipRepository();

      final MembershipHydrationResult result = await repository.loadMemberships(
        userId: 'demo-user',
      );

      expect(result, isA<HydrationSucceeded>());
      final List<OrganizationMembership> memberships =
          (result as HydrationSucceeded).memberships;
      expect(memberships, hasLength(1));
      final OrganizationMembership membership = memberships.single;
      expect(membership.organizationId, 'org-demo');
      expect(membership.organizationName, 'Demo Firm');
      expect(membership.role, UserRole.partner);
      expect(membership.status, MembershipStatus.active);
      expect(membership.isActive, isTrue);
    });

    test('matches the demo auth session membership (single source)', () {
      // The fake repository and the fake auth gateway must agree on the demo
      // membership so hydrated sessions render identically to demo sessions.
      // The partner role is the P3.2 Task 8 reconciliation with the org
      // gateway's roster seed (the demo user is the org creator).
      expect(
        FakeMembershipRepository.demoMembership,
        const OrganizationMembership(
          organizationId: 'org-demo',
          organizationName: 'Demo Firm',
          role: UserRole.partner,
          status: MembershipStatus.active,
        ),
      );
    });

    test('derives memberships from a bound fake org gateway (P3.3)', () async {
      final FakeOrganizationGateway gateway = FakeOrganizationGateway();
      await gateway.createOrganization(name: 'Second Firm');
      final FakeMembershipRepository repository = FakeMembershipRepository(
        organizationGateway: gateway,
      );

      final MembershipHydrationResult result = await repository.loadMemberships(
        userId: 'demo-user',
      );

      expect(result, isA<HydrationSucceeded>());
      final List<OrganizationMembership> memberships =
          (result as HydrationSucceeded).memberships;
      expect(memberships, hasLength(2));
      expect(
        memberships.map((OrganizationMembership m) => m.organizationId),
        <String>['org-demo', 'org-2'],
      );
      expect(memberships.last.organizationName, 'Second Firm');
      expect(memberships.last.isActive, isTrue);
    });
  });
}
