import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/admin/audit_entry.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_gateway.dart';

/// Hand-rolled fake of the [SupabasePlatformAdminApi] seam: records calls and
/// answers with canned rows or [SupabasePlatformAdminException]s, so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabasePlatformAdminApi implements SupabasePlatformAdminApi {
  List<Map<String, dynamic>> orgRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> memberRows = <Map<String, dynamic>>[];
  SupabasePlatformAdminException? listError;
  SupabasePlatformAdminException? voidError;
  final List<String> calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> listOrganizations() async {
    calls.add('orgs');
    if (listError != null) {
      throw listError!;
    }
    return orgRows;
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers() async {
    calls.add('members');
    if (listError != null) {
      throw listError!;
    }
    return memberRows;
  }

  @override
  Future<void> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('suspend:$organizationId:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('reactivate:$organizationId:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> deleteDemoAccount({required String userId}) async {
    calls.add('delete:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readPlatformAudit() async {
    calls.add('platformAudit');
    if (listError != null) {
      throw listError!;
    }
    return auditRows;
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit(String organizationId) async {
    calls.add('orgAudit:$organizationId');
    if (listError != null) {
      throw listError!;
    }
    return auditRows;
  }

  List<Map<String, dynamic>> auditRows = <Map<String, dynamic>>[];
}

void main() {
  late _StubSupabasePlatformAdminApi api;
  late SupabasePlatformAdminGateway gateway;

  setUp(() {
    api = _StubSupabasePlatformAdminApi();
    gateway = SupabasePlatformAdminGateway(api);
  });

  group('listOrganizations', () {
    test('maps metadata rows to OrganizationSummary', () async {
      api.orgRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'name': 'Demo Firm',
          'created_at': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<OrganizationSummary>> outcome = await gateway
          .listOrganizations();

      final OrganizationSummary org = outcome.valueOrNull!.single;
      expect(org.id, 'org-1');
      expect(org.name, 'Demo Firm');
      expect(
        org.createdAt,
        DateTime.parse('2026-07-25T10:00:00.000Z').toLocal(),
      );
      expect(api.calls, <String>['orgs']);
    });

    test('surfaces a row missing id/name loudly', () async {
      api.orgRows = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Only Name'},
      ];

      final OrgOutcome<List<OrganizationSummary>> outcome = await gateway
          .listOrganizations();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });

    test('maps a non-owner denial', () async {
      api.listError = const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<List<OrganizationSummary>> outcome = await gateway
          .listOrganizations();

      expect(
        outcome.failureOrNull,
        const OrgFailure(
          kind: OrgFailureKind.denied,
          message: 'permission denied',
        ),
      );
    });
  });

  group('listMembers', () {
    test('maps metadata rows to OrgMember', () async {
      api.memberRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'user_id': 'u-1',
          'display_name': 'Amira Hassan',
          'locale': 'ar',
          'role': 'partner',
          'status': 'active',
          'created_at': '2026-07-25T10:00:00.000Z',
          'updated_at': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();

      final OrgMember member = outcome.valueOrNull!.single;
      expect(member.organizationId, 'org-1');
      expect(member.userId, 'u-1');
      expect(member.displayName, 'Amira Hassan');
      expect(member.locale, 'ar');
      expect(member.role, UserRole.partner);
      expect(member.status, MembershipStatus.active);
      expect(api.calls, <String>['members']);
    });

    test('falls back to the user id when display name is absent', () async {
      api.memberRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'user_id': 'u-2',
          'display_name': null,
          'locale': null,
          'role': 'client',
          'status': 'suspended',
          'created_at': '2026-07-25T10:00:00.000Z',
          'updated_at': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();

      final OrgMember member = outcome.valueOrNull!.single;
      expect(member.displayName, 'u-2');
      expect(member.status, MembershipStatus.suspended);
    });

    test('surfaces an unknown role name loudly', () async {
      api.memberRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'user_id': 'u-1',
          'display_name': 'X',
          'role': 'admin',
          'status': 'active',
          'created_at': '2026-07-25T10:00:00.000Z',
          'updated_at': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });

    test('surfaces a row missing user_id loudly', () async {
      api.memberRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'display_name': 'X',
          'role': 'client',
          'status': 'active',
          'created_at': '2026-07-25T10:00:00.000Z',
          'updated_at': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });
  });

  group('platform actions', () {
    test('suspendMembership forwards org + user', () async {
      final OrgOutcome<void> outcome = await gateway.suspendMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['suspend:org-1:u-2']);
    });

    test('reactivateMembership forwards org + user', () async {
      final OrgOutcome<void> outcome = await gateway.reactivateMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['reactivate:org-1:u-2']);
    });

    test('maps a void denial', () async {
      api.voidError = const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<void> outcome = await gateway.suspendMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
    });

    test('deleteDemoAccount trims and forwards the user id', () async {
      final OrgOutcome<void> outcome = await gateway.deleteDemoAccount(
        userId: '  u-9 ',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['delete:u-9']);
    });
    test(
      'deleteDemoAccount rejects a blank user id without calling the seam',
      () async {
        final OrgOutcome<void> outcome = await gateway.deleteDemoAccount(
          userId: '   ',
        );

        // Missing input is not a permission denial: honest `unknown`.
        expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
        expect(api.calls, isEmpty);
      },
    );
  });

  group('readPlatformAudit', () {
    test('maps redacted audit rows to AuditEntry', () async {
      api.auditRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'actor_user_id': 'owner-1',
          'action': 'organization_created',
          'outcome': 'succeeded',
          'organization_id': 'org-1',
          'resource_type': 'organization',
          'resource_id': 'org-1',
          'correlation_id': 'audit-0001',
          'redacted_summary': 'Organization created (metadata only)',
          'server_timestamp': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<AuditEntry>> outcome = await gateway
          .readPlatformAudit();

      final AuditEntry entry = outcome.valueOrNull!.single;
      expect(entry.id, 1);
      expect(entry.action, 'organization_created');
      expect(entry.outcome, 'succeeded');
      expect(entry.resourceType, 'organization');
      expect(entry.resourceId, 'org-1');
      expect(entry.correlationId, 'audit-0001');
      expect(entry.redactedSummary, 'Organization created (metadata only)');
      expect(
        entry.serverTimestamp,
        DateTime.parse('2026-07-25T10:00:00.000Z').toLocal(),
      );
      expect(entry.actorUserId, 'owner-1');
      expect(entry.organizationId, 'org-1');
      expect(api.calls, <String>['platformAudit']);
    });

    test('surfaces a row missing required columns loudly', () async {
      api.auditRows = <Map<String, dynamic>>[
        <String, dynamic>{'action': 'organization_created'},
      ];

      final OrgOutcome<List<AuditEntry>> outcome = await gateway
          .readPlatformAudit();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });

    test('surfaces a non-int id loudly', () async {
      api.auditRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'not-an-int',
          'action': 'organization_created',
          'outcome': 'succeeded',
          'redacted_summary': 'x',
          'server_timestamp': '2026-07-25T10:00:00.000Z',
        },
      ];

      final OrgOutcome<List<AuditEntry>> outcome = await gateway
          .readPlatformAudit();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });

    test(
      'surfaces a wrong-typed uuid column loudly (no raw TypeError)',
      () async {
        // A uuid column arriving as a non-string (provider drift) must map
        // to a typed failure, never a raw TypeError across the boundary.
        api.auditRows = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'action': 'organization_created',
            'outcome': 'succeeded',
            'resource_id': 42, // wrong type for a uuid
            'redacted_summary': 'x',
            'server_timestamp': '2026-07-25T10:00:00.000Z',
          },
        ];

        final OrgOutcome<List<AuditEntry>> outcome = await gateway
            .readPlatformAudit();

        expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
      },
    );

    test('maps a non-owner denial (AC-7, never empty-success)', () async {
      api.listError = const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<List<AuditEntry>> outcome = await gateway
          .readPlatformAudit();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      expect(outcome.valueOrNull, isNull);
    });

    test('maps a provider failure to providerUnavailable', () async {
      api.listError = const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );

      final OrgOutcome<List<AuditEntry>> outcome = await gateway
          .readPlatformAudit();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.providerUnavailable);
    });
  });

  group('readOrgAudit', () {
    test('forwards the org id and maps rows', () async {
      api.auditRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'action': 'member_invited',
          'outcome': 'succeeded',
          'resource_type': 'membership',
          'correlation_id': 'audit-1007',
          'redacted_summary': 'Member invited (metadata only)',
          'server_timestamp': '2026-07-26T11:30:00.000Z',
        },
      ];

      final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
        organizationId: 'org-9',
      );

      final AuditEntry entry = outcome.valueOrNull!.single;
      expect(entry.id, 7);
      expect(entry.action, 'member_invited');
      // Org variant: no actor/org columns on the row.
      expect(entry.actorUserId, isNull);
      expect(entry.organizationId, isNull);
      expect(api.calls, <String>['orgAudit:org-9']);
    });

    test('maps a non-owner denial (AC-7)', () async {
      api.listError = const SupabasePlatformAdminException(
        kind: SupabasePlatformAdminFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      expect(outcome.valueOrNull, isNull);
    });
  });
}
