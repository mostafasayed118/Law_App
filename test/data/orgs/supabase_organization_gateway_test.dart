import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/orgs/supabase_organization_gateway.dart';

/// Hand-rolled fake of the [SupabaseOrgApi] seam: records calls and answers
/// with canned success values or [SupabaseOrgException]s, so the gateway's
/// domain mapping is tested without a provider.
class _StubSupabaseOrgApi implements SupabaseOrgApi {
  Object? createResult;
  SupabaseOrgException? createError;
  List<Map<String, dynamic>> listRows = <Map<String, dynamic>>[];
  SupabaseOrgException? listError;
  String? inviteToken;
  SupabaseOrgException? inviteError;
  SupabaseOrgException? voidError;
  final List<String> calls = <String>[];

  @override
  Future<String> createOrganization({required String name}) async {
    calls.add('create:$name');
    if (createError != null) {
      throw createError!;
    }
    return createResult as String;
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async {
    calls.add('list:$organizationId');
    if (listError != null) {
      throw listError!;
    }
    return listRows;
  }

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    calls.add('invite:$organizationId:$email:$role');
    if (inviteError != null) {
      throw inviteError!;
    }
    return inviteToken ?? 'token-1';
  }

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    calls.add('change:$organizationId:$userId:$role');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('suspend:$organizationId:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('reactivate:$organizationId:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('remove:$organizationId:$userId');
    if (voidError != null) {
      throw voidError!;
    }
  }
}

void main() {
  late _StubSupabaseOrgApi api;
  late SupabaseOrganizationGateway gateway;

  setUp(() {
    api = _StubSupabaseOrgApi();
    gateway = SupabaseOrganizationGateway(api);
  });

  group('createOrganization', () {
    test('trims the name and maps the provider id', () async {
      api.createResult = 'org-7';

      final OrgOutcome<OrganizationSummary> outcome = await gateway
          .createOrganization(name: '  New Firm  ');

      expect(outcome.isSuccess, isTrue);
      final OrganizationSummary summary = outcome.valueOrNull!;
      expect(summary.id, 'org-7');
      expect(summary.name, 'New Firm');
      expect(api.calls, <String>['create:New Firm']);
    });

    test('rejects an empty name without calling the seam', () async {
      final OrgOutcome<OrganizationSummary> outcome = await gateway
          .createOrganization(name: '   ');

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidName);
      expect(api.calls, isEmpty);
    });

    test('maps a denied provider error', () async {
      api.createError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<OrganizationSummary> outcome = await gateway
          .createOrganization(name: 'New Firm');

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
    test('maps rows to domain members', () async {
      api.listRows = <Map<String, dynamic>>[
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

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers(
        organizationId: 'org-1',
      );

      final OrgMember member = outcome.valueOrNull!.single;
      expect(member.userId, 'u-1');
      expect(member.displayName, 'Amira Hassan');
      expect(member.locale, 'ar');
      expect(member.role, UserRole.partner);
      expect(member.status, MembershipStatus.active);
      expect(member.isActive, isTrue);
    });

    test('surfaces an unknown role name as a loud failure', () async {
      api.listRows = <Map<String, dynamic>>[
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

      final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers(
        organizationId: 'org-1',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
    });
  });

  group('inviteMember', () {
    test('sends the server role name and returns the token', () async {
      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: 'org-1',
        email: '  new@y.test ',
        role: UserRole.attorney,
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.valueOrNull!.token, 'token-1');
      expect(outcome.valueOrNull!.email, 'new@y.test');
      expect(api.calls, <String>['invite:org-1:new@y.test:attorney']);
    });

    test('rejects a role with no server counterpart', () async {
      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: 'org-1',
        email: 'new@y.test',
        role: UserRole.complianceOfficer,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidRole);
      expect(api.calls, isEmpty);
    });

    test('maps the duplicate-member error', () async {
      api.inviteError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.duplicateMember,
        message: 'user already has a membership in this organization',
      );

      final OrgOutcome<InviteResult> outcome = await gateway.inviteMember(
        organizationId: 'org-1',
        email: 'existing@y.test',
        role: UserRole.client,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.duplicateMember);
    });
  });

  group('void operations', () {
    test('changeMemberRole forwards the server role name', () async {
      final OrgOutcome<void> outcome = await gateway.changeMemberRole(
        organizationId: 'org-1',
        userId: 'u-2',
        role: UserRole.client,
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['change:org-1:u-2:client']);
    });

    test('rejects a non-server role before calling the seam', () async {
      final OrgOutcome<void> outcome = await gateway.changeMemberRole(
        organizationId: 'org-1',
        userId: 'u-2',
        role: UserRole.admin,
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidRole);
      expect(api.calls, isEmpty);
    });

    test('maps the last-partner error on suspend', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.lastPartner,
        message: 'organization must retain at least one active partner',
      );

      final OrgOutcome<void> outcome = await gateway.suspendMember(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.lastPartner);
    });

    test('removeMember forwards and maps denials', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<void> outcome = await gateway.removeMember(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      expect(api.calls, <String>['remove:org-1:u-2']);
    });
  });
}
