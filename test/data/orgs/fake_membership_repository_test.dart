import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';

void main() {
  group('FakeMembershipRepository', () {
    test('hydrates the demo active membership for any caller', () async {
      final FakeMembershipRepository repository = FakeMembershipRepository();

      final List<OrganizationMembership> memberships = await repository
          .loadMemberships(userId: 'demo-user');

      expect(memberships, hasLength(1));
      final OrganizationMembership membership = memberships.single;
      expect(membership.organizationId, 'org-demo');
      expect(membership.organizationName, 'Demo Firm');
      expect(membership.role, UserRole.client);
      expect(membership.status, MembershipStatus.active);
      expect(membership.isActive, isTrue);
    });

    test('matches the demo auth session membership (single source)', () {
      // The fake repository and the fake auth gateway must agree on the demo
      // membership so hydrated sessions render identically to demo sessions.
      expect(
        FakeMembershipRepository.demoMembership,
        const OrganizationMembership(
          organizationId: 'org-demo',
          organizationName: 'Demo Firm',
          role: UserRole.client,
          status: MembershipStatus.active,
        ),
      );
    });
  });
}
