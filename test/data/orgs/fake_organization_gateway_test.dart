import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';

void main() {
  group('FakeOrganizationGateway', () {
    late FakeOrganizationGateway gateway;

    setUp(() {
      gateway = FakeOrganizationGateway();
    });

    test('seeds the demo org with the demo user as partner', () async {
      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );

      final OrgMember demo = outcome.valueOrNull!.single;
      expect(demo.userId, FakeOrganizationGateway.demoUserId);
      expect(demo.role, UserRole.partner);
      expect(demo.status, MembershipStatus.active);
    });

    test('createOrganization makes the actor the initial partner', () async {
      final OrgOutcome<OrganizationSummary> created = await gateway
          .createOrganization(name: 'Second Firm');

      expect(created.isSuccess, isTrue);
      final OrgOutcome<List<OrgMember>> roster = await gateway.listMembers(
        organizationId: created.valueOrNull!.id,
      );
      final OrgMember partner = roster.valueOrNull!.single;
      expect(partner.role, UserRole.partner);
    });

    test('rejects an empty organization name', () async {
      final OrgOutcome<OrganizationSummary> outcome = await gateway
          .createOrganization(name: '  ');

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidName);
    });

    test('invite adds an invited member and returns a token', () async {
      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@y.test',
        role: UserRole.attorney,
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.valueOrNull!.token, isNotEmpty);
      final OrgOutcome<List<OrgMember>> roster = await gateway.listMembers(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      expect(
        roster.valueOrNull!.any(
          (OrgMember m) =>
              m.displayName == 'new@y.test' &&
              m.status == MembershipStatus.invited,
        ),
        isTrue,
      );
    });

    test('invite rejects an existing member email', () async {
      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'Demo user',
        role: UserRole.client,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.duplicateMember);
    });

    test('invite rejects a role with no server counterpart', () async {
      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@y.test',
        role: UserRole.complianceOfficer,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidRole);
    });

    test('demoting the last partner fails with lastPartner', () async {
      final OrgOutcome<InviteResult> invited = await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@y.test',
        role: UserRole.partner,
      );
      final String newUserId = invited.valueOrNull!.email;

      final OrgOutcome<void> demoted = await gateway.changeMemberRole(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: newUserId,
        role: UserRole.client,
      );
      expect(demoted.isSuccess, isTrue);

      final OrgOutcome<void> last = await gateway.changeMemberRole(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
        role: UserRole.client,
      );
      expect(last.failureOrNull?.kind, OrgFailureKind.lastPartner);
    });

    test('suspend of the last active partner fails', () async {
      await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@y.test',
        role: UserRole.partner,
      );

      final OrgOutcome<void> suspend = await gateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
      );

      expect(suspend.failureOrNull?.kind, OrgFailureKind.lastPartner);
    });

    test('remove of the demo self-identity is denied', () async {
      final OrgOutcome<void> outcome = await gateway.removeMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
    });

    test('suspend + reactivate round trip', () async {
      await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'new@y.test',
        role: UserRole.client,
      );

      final OrgOutcome<void> suspended = await gateway.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'new@y.test',
      );
      expect(suspended.isSuccess, isTrue);

      final OrgOutcome<void> reactivated = await gateway.reactivateMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'new@y.test',
      );
      expect(reactivated.isSuccess, isTrue);

      final OrgOutcome<List<OrgMember>> roster = await gateway.listMembers(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      final OrgMember member = roster.valueOrNull!.firstWhere(
        (OrgMember m) => m.userId == 'new@y.test',
      );
      expect(member.status, MembershipStatus.active);
    });
  });
}
