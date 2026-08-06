import 'package:flutter_test/flutter_test.dart';
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
}
