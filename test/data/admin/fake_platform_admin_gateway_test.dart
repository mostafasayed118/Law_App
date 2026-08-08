import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/admin/audit_entry.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/admin/fake_platform_admin_gateway.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';

void main() {
  group('FakePlatformAdminGateway', () {
    late FakeOrganizationGateway orgGateway;
    late FakePlatformAdminGateway gateway;

    setUp(() {
      orgGateway = FakeOrganizationGateway();
      gateway = FakePlatformAdminGateway(organizationGateway: orgGateway);
    });

    group('owner positive paths', () {
      test('lists the seeded organization metadata', () async {
        final OrgOutcome<List<OrganizationSummary>> outcome = await gateway
            .listOrganizations();

        final List<OrganizationSummary> orgs = outcome.valueOrNull!;
        expect(orgs, hasLength(1));
        expect(orgs.single.name, 'Demo Firm');
        expect(orgs.single.id, FakeOrganizationGateway.demoOrganizationId);
      });

      test('lists the seeded member metadata', () async {
        final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();

        final List<OrgMember> members = outcome.valueOrNull!;
        expect(members, hasLength(1));
        final OrgMember demo = members.single;
        expect(demo.userId, FakeOrganizationGateway.demoUserId);
        expect(demo.role, UserRole.partner);
        expect(demo.isActive, isTrue);
      });

      test('a created org joins the admin org list (shared state)', () async {
        await orgGateway.createOrganization(name: 'Second Firm');

        final OrgOutcome<List<OrganizationSummary>> outcome = await gateway
            .listOrganizations();

        expect(outcome.valueOrNull, hasLength(2));
        expect(outcome.valueOrNull!.last.name, 'Second Firm');
      });

      test(
        'invited rows never appear in the member list (profiles join)',
        () async {
          await orgGateway.inviteMember(
            organizationId: FakeOrganizationGateway.demoOrganizationId,
            email: 'new@y.test',
            role: UserRole.client,
          );

          final OrgOutcome<List<OrgMember>> outcome = await gateway
              .listMembers();

          // The real RPC joins profiles; invited rows (no profile yet) are
          // excluded — only the demo user remains.
          expect(outcome.valueOrNull, hasLength(1));
        },
      );

      test('suspend + reactivate delegate to the shared org state', () async {
        await orgGateway.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'new@y.test',
          role: UserRole.client,
        );

        final OrgOutcome<void> suspended = await gateway.suspendMembership(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'new@y.test',
        );
        expect(suspended.isSuccess, isTrue);

        // The change lands in the shared org roster (the platform member
        // list excludes invited rows — pinned by its own test).
        final OrgOutcome<List<OrgMember>> roster = await orgGateway.listMembers(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
        );
        expect(
          roster.valueOrNull!
              .firstWhere((OrgMember m) => m.userId == 'new@y.test')
              .status,
          MembershipStatus.suspended,
        );

        final OrgOutcome<void> reactivated = await gateway.reactivateMembership(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'new@y.test',
        );
        expect(reactivated.isSuccess, isTrue);
      });

      test('deleteDemoAccount removes the target from every roster', () async {
        await orgGateway.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'new@y.test',
          role: UserRole.client,
        );
        final OrgOutcome<void> deleted = await gateway.deleteDemoAccount(
          userId: 'new@y.test',
        );

        expect(deleted.isSuccess, isTrue);
        final OrgOutcome<List<OrgMember>> roster = await orgGateway.listMembers(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
        );
        expect(
          roster.valueOrNull!.any((OrgMember m) => m.userId == 'new@y.test'),
          isFalse,
        );
      });
    });

    group('non-owner → denied, never empty-success (AC-7)', () {
      late FakePlatformAdminGateway nonOwner;

      setUp(() {
        nonOwner = FakePlatformAdminGateway(
          organizationGateway: orgGateway,
          demoIsPlatformOwner: false,
        );
      });

      test('listOrganizations is denied, not empty', () async {
        final OrgOutcome<List<OrganizationSummary>> outcome = await nonOwner
            .listOrganizations();

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
        expect(outcome.valueOrNull, isNull);
      });

      test('listMembers is denied, not empty', () async {
        final OrgOutcome<List<OrgMember>> outcome = await nonOwner
            .listMembers();

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
        expect(outcome.valueOrNull, isNull);
      });

      test('suspendMembership is denied', () async {
        final OrgOutcome<void> outcome = await nonOwner.suspendMembership(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'u-2',
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      });

      test('reactivateMembership is denied', () async {
        final OrgOutcome<void> outcome = await nonOwner.reactivateMembership(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'u-2',
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      });

      test('deleteDemoAccount is denied', () async {
        final OrgOutcome<void> outcome = await nonOwner.deleteDemoAccount(
          userId: 'u-9',
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      });
    });

    group('never self (RPC refuses auth.uid())', () {
      test('deleteDemoAccount refuses the demo identity', () async {
        final OrgOutcome<void> outcome = await gateway.deleteDemoAccount(
          userId: FakeOrganizationGateway.demoUserId,
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      });

      test('the demo user survives the refusal', () async {
        await gateway.deleteDemoAccount(
          userId: FakeOrganizationGateway.demoUserId,
        );

        final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();
        expect(outcome.valueOrNull, hasLength(1));
        expect(outcome.valueOrNull!.single.userId, 'demo-user');
      });
    });

    group('audit reads (D-AUD5)', () {
      test('platform audit is deterministic, non-PII, redacted-only', () async {
        final OrgOutcome<List<AuditEntry>> first = await gateway
            .readPlatformAudit();
        final OrgOutcome<List<AuditEntry>> second = await gateway
            .readPlatformAudit();

        final List<AuditEntry> rows = first.valueOrNull!;
        expect(rows, hasLength(5));
        expect(rows, second.valueOrNull);
        // Every row is redacted metadata: correlation ids present, no
        // credentials/content-shaped fields.
        for (final AuditEntry entry in rows) {
          expect(entry.correlationId, isNotNull);
          expect(entry.redactedSummary, contains('metadata only'));
        }
        expect(rows.first.action, 'organization_created');
        expect(rows.first.actorUserId, FakeOrganizationGateway.demoUserId);
        expect(
          rows.first.organizationId,
          FakeOrganizationGateway.demoOrganizationId,
        );
      });

      test('org audit is scoped to the demo org', () async {
        final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
        );

        expect(outcome.valueOrNull, hasLength(3));
        expect(outcome.valueOrNull!.first.action, 'organization_created');
      });

      test('a foreign org id reads as an honest empty trail', () async {
        final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
          organizationId: 'org-foreign',
        );

        expect(outcome.isSuccess, isTrue);
        expect(outcome.valueOrNull, isEmpty);
      });

      test(
        'non-owner audit reads are denied, never empty-success (AC-7)',
        () async {
          final FakePlatformAdminGateway nonOwnerAudit =
              FakePlatformAdminGateway(
                organizationGateway: orgGateway,
                demoIsPlatformOwner: false,
              );
          final OrgOutcome<List<AuditEntry>> platform = await nonOwnerAudit
              .readPlatformAudit();
          final OrgOutcome<List<AuditEntry>> org = await nonOwnerAudit
              .readOrgAudit(
                organizationId: FakeOrganizationGateway.demoOrganizationId,
              );

          expect(platform.failureOrNull?.kind, OrgFailureKind.denied);
          expect(platform.valueOrNull, isNull);
          expect(org.failureOrNull?.kind, OrgFailureKind.denied);
          expect(org.valueOrNull, isNull);
        },
      );
    });
  });
}
