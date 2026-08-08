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
  List<Map<String, dynamic>> auditRows = <Map<String, dynamic>>[];
  SupabaseOrgException? auditError;
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
  Future<List<Map<String, dynamic>>> listMyMemberships() async =>
      <Map<String, dynamic>>[];

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

  @override
  Future<String> resendInvitation({required String invitationId}) async {
    calls.add('resend:$invitationId');
    if (voidError != null) {
      throw voidError!;
    }
    return 'token-resent';
  }

  @override
  Future<void> revokeInvitation({required String invitationId}) async {
    calls.add('revoke:$invitationId');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<void> deleteMyAccount() async {
    calls.add('delete-account');
    if (voidError != null) {
      throw voidError!;
    }
  }

  @override
  Future<String> acceptInvitation({required String token}) async {
    calls.add('accept:$token');
    if (voidError != null) {
      throw voidError!;
    }
    return 'membership-1';
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async {
    calls.add('audit:$organizationId');
    if (auditError != null) {
      throw auditError!;
    }
    return auditRows;
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

    test(
      'maps an invited row by email with a real invitation id (R1)',
      () async {
        api.listRows = <Map<String, dynamic>>[
          <String, dynamic>{
            'organization_id': 'org-1',
            // RPC contract §8: invited rows carry no user id yet.
            'user_id': null,
            'invitation_id': 'inv-7',
            'email': 'new@y.test',
            'display_name': null,
            'locale': null,
            'role': 'client',
            'status': 'invited',
            'created_at': '2026-07-25T10:00:00.000Z',
            'updated_at': '2026-07-25T10:00:00.000Z',
          },
        ];

        final OrgOutcome<List<OrgMember>> outcome = await gateway.listMembers(
          organizationId: 'org-1',
        );

        final OrgMember invited = outcome.valueOrNull!.single;
        expect(invited.userId, 'new@y.test');
        expect(invited.displayName, 'new@y.test');
        expect(invited.locale, isNull);
        expect(invited.role, UserRole.client);
        expect(invited.status, MembershipStatus.invited);
        expect(invited.invitationId, 'inv-7');
      },
    );

    test('surfaces a row with neither user_id nor email loudly', () async {
      api.listRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'user_id': null,
          'email': null,
          'role': 'client',
          'status': 'invited',
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

  group('invite lifecycle (Phase 2)', () {
    test(
      'resendInvitation forwards the id and returns the fresh token',
      () async {
        final OrgOutcome<String> outcome = await gateway.resendInvitation(
          invitationId: 'inv-7',
        );

        expect(outcome.isSuccess, isTrue);
        expect(outcome.valueOrNull, 'token-resent');
        expect(api.calls, <String>['resend:inv-7']);
      },
    );

    test('resendInvitation maps invalid-invitation errors', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.invalidInvitation,
        message: 'invitation not found',
      );

      final OrgOutcome<String> outcome = await gateway.resendInvitation(
        invitationId: 'inv-9',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidInvitation);
    });

    test('revokeInvitation forwards the id', () async {
      final OrgOutcome<void> outcome = await gateway.revokeInvitation(
        invitationId: 'inv-7',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['revoke:inv-7']);
    });

    test('revokeInvitation maps invalid-invitation errors', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.invalidInvitation,
        message: 'only pending invitations can be revoked',
      );

      final OrgOutcome<void> outcome = await gateway.revokeInvitation(
        invitationId: 'inv-9',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidInvitation);
    });

    test('deleteMyAccount forwards without params', () async {
      final OrgOutcome<void> outcome = await gateway.deleteMyAccount();

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['delete-account']);
    });

    test('deleteMyAccount maps denials', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<void> outcome = await gateway.deleteMyAccount();

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
    });

    test(
      'acceptInvitation trims the token and returns the membership id',
      () async {
        final OrgOutcome<String> outcome = await gateway.acceptInvitation(
          token: '  the-token ',
        );

        expect(outcome.isSuccess, isTrue);
        expect(outcome.valueOrNull, 'membership-1');
        expect(api.calls, <String>['accept:the-token']);
      },
    );

    test(
      'acceptInvitation rejects a blank token without calling the seam',
      () async {
        final OrgOutcome<String> outcome = await gateway.acceptInvitation(
          token: '   ',
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidInvitation);
        expect(api.calls, isEmpty);
      },
    );

    test('acceptInvitation maps invalid-invitation errors', () async {
      api.voidError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.invalidInvitation,
        message: 'invalid invitation',
      );

      final OrgOutcome<String> outcome = await gateway.acceptInvitation(
        token: 'bad-token',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.invalidInvitation);
    });
  });

  group('readOrgAudit', () {
    test('maps rows to redacted audit entries', () async {
      api.auditRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'action': 'member:role/change',
          'outcome': 'allowed',
          'resource_type': 'membership',
          'resource_id': 'u-1',
          'correlation_id': 'audit-org-1-1',
          'redacted_summary': 'role change',
          'server_timestamp': '2026-07-25T10:00:00.000000Z',
        },
      ];

      final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(outcome.isSuccess, isTrue);
      expect(api.calls, <String>['audit:org-1']);
      final AuditEntry entry = outcome.valueOrNull!.single;
      expect(entry.id, 1);
      expect(entry.action, 'member:role/change');
      expect(entry.outcome, 'allowed');
      expect(entry.resourceType, 'membership');
      expect(entry.resourceId, 'u-1');
      expect(entry.correlationId, 'audit-org-1-1');
      expect(entry.redactedSummary, 'role change');
      expect(entry.serverTimestamp, DateTime.utc(2026, 7, 25, 10));
      expect(entry.actorUserId, isNull);
      expect(entry.organizationId, isNull);
    });

    test('maps permission denied to the distinct denied kind', () async {
      api.auditError = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.denied,
        message: 'permission denied',
      );

      final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
    });

    test(
      'surfaces a malformed row as unknown, never a raw TypeError',
      () async {
        api.auditRows = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'not-an-int'},
        ];

        final OrgOutcome<List<AuditEntry>> outcome = await gateway.readOrgAudit(
          organizationId: 'org-1',
        );

        expect(outcome.failureOrNull?.kind, OrgFailureKind.unknown);
      },
    );
  });
}
