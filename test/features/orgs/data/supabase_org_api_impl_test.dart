import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/orgs/data/supabase_org_api.dart';
import 'package:legalhub/features/orgs/data/supabase_org_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseOrgApiImpl', () {
    late List<String> calls;
    late Map<String, Object?> data;
    late Map<String, PostgrestException> errors;
    late Set<String> timeouts;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late List<String?> tableFilterColumns;
    late List<Object?> tableFilterValues;
    late SupabaseOrgApiImpl api;

    setUp(() {
      calls = <String>[];
      data = <String, Object?>{};
      errors = <String, PostgrestException>{};
      timeouts = <String>{};
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      tableFilterColumns = <String?>[];
      tableFilterValues = <Object?>[];
      api = SupabaseOrgApiImpl(
        (String function, Map<String, dynamic> params) async {
          calls.add('$function:${params.values.join(',')}');
          if (timeouts.contains(function)) {
            throw TimeoutException('slow provider');
          }
          final PostgrestException? error = errors[function];
          if (error != null) {
            throw error;
          }
          return PostgrestResponse<dynamic>(data: data[function], count: 0);
        },
        (
          String table,
          String columns, {
          String? filterColumn,
          Object? filterValue,
        }) async {
          calls.add('$table:$columns');
          tableFilterColumns.add(filterColumn);
          tableFilterValues.add(filterValue);
          final PostgrestException? error = tableErrors[table];
          if (error != null) {
            throw error;
          }
          return tableData[table] ?? const <Map<String, dynamic>>[];
        },
      );
    });

    test(
      'createOrganization sends p_name and returns the provider id',
      () async {
        data['create_organization'] = 'org-42';

        final String id = await api.createOrganization(name: 'New Firm');

        expect(id, 'org-42');
        expect(calls, <String>['create_organization:New Firm']);
      },
    );

    test('createOrganization surfaces a missing id as unknown', () async {
      data['create_organization'] = null;

      await expectLater(
        api.createOrganization(name: 'New Firm'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.unknown,
          ),
        ),
      );
    });

    test('maps permission denied to the denied kind', () async {
      errors['create_organization'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.createOrganization(name: 'New Firm'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test('inviteMember sends org, email, role and returns the token', () async {
      data['invite_member'] = 'one-time-token';

      final String token = await api.inviteMember(
        organizationId: 'org-1',
        email: 'x@y.test',
        role: 'client',
      );

      expect(token, 'one-time-token');
      expect(calls, <String>['invite_member:org-1,x@y.test,client']);
    });

    test('maps the duplicate-member raise to duplicateMember', () async {
      errors['invite_member'] = const PostgrestException(
        message: 'user already has a membership in this organization',
      );

      await expectLater(
        api.inviteMember(
          organizationId: 'org-1',
          email: 'member@y.test',
          role: 'client',
        ),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.duplicateMember,
          ),
        ),
      );
    });

    test('maps the last-partner raise to lastPartner', () async {
      errors['change_member_role'] = const PostgrestException(
        message: 'organization must retain at least one active partner',
      );

      await expectLater(
        api.changeMemberRole(
          organizationId: 'org-1',
          userId: 'u-1',
          role: 'client',
        ),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.lastPartner,
          ),
        ),
      );
    });

    test('void RPCs map the self-removal raise to denied', () async {
      errors['remove_membership'] = const PostgrestException(
        message: 'cannot remove yourself; use delete_my_account',
      );

      await expectLater(
        api.removeMember(organizationId: 'org-1', userId: 'u-1'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test('listMembers sends the org id and returns only map rows', () async {
      data['list_org_members_metadata'] = <dynamic>[
        <String, dynamic>{'user_id': 'u-1'},
        'not-a-map',
      ];

      final List<Map<String, dynamic>> rows = await api.listMembers(
        organizationId: 'org-1',
      );

      expect(rows, hasLength(1));
      expect(calls, <String>['list_org_members_metadata:org-1']);
    });

    test(
      'listAssignableMembers sends the matter id and returns only map rows',
      () async {
        data['list_matter_assignable_members'] = <dynamic>[
          <String, dynamic>{'user_id': 'u-1', 'display_name': 'Amira'},
          'not-a-map',
        ];

        final List<Map<String, dynamic>> rows = await api.listAssignableMembers(
          matterId: 'matter-1',
        );

        expect(rows, hasLength(1));
        expect(calls, <String>['list_matter_assignable_members:matter-1']);
      },
    );

    test('listAssignableMembers maps a denial to the denied kind', () async {
      errors['list_matter_assignable_members'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.listAssignableMembers(matterId: 'matter-1'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'listAssignableMembers maps an empty response to an empty list',
      () async {
        data['list_matter_assignable_members'] = null;

        final List<Map<String, dynamic>> rows = await api.listAssignableMembers(
          matterId: 'matter-1',
        );

        expect(rows, isEmpty);
      },
    );

    test('listMyMemberships selects user_id + the org embed and projects the '
        'caller row only', () async {
      tableData['memberships'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'organization_id': 'org-1',
          'user_id': 'u-1',
          'role': 'partner',
          'status': 'active',
          'organizations': <String, dynamic>{'name': 'Demo Firm'},
        },
        <String, dynamic>{
          'organization_id': 'org-2',
          'user_id': 'u-2',
          'role': 'partner',
          'status': 'active',
          'organizations': <String, dynamic>{'name': 'Co-member Firm'},
        },
      ];

      final List<Map<String, dynamic>> rows = await api.listMyMemberships(
        userId: 'u-1',
      );

      expect(rows, hasLength(1));
      expect(rows.single['organization_id'], 'org-1');
      expect(calls, <String>[
        'memberships:organization_id, user_id, role, status, '
            'organizations(name)',
      ]);
    });

    test(
      'listMyMemberships filters the memberships read by user_id server-side '
      '(P1: >200 visible co-member rows cannot truncate the caller away)',
      () async {
        tableData['memberships'] = const <Map<String, dynamic>>[];

        await api.listMyMemberships(userId: 'u-1');

        expect(tableFilterColumns, <String?>['user_id']);
        expect(tableFilterValues, <Object?>['u-1']);
      },
    );

    test('readOrgAudit sends the org id and returns only map rows', () async {
      data['read_org_audit'] = <dynamic>[
        <String, dynamic>{'id': 1, 'action': 'member:role/change'},
        'not-a-map',
      ];

      final List<Map<String, dynamic>> rows = await api.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(rows, hasLength(1));
      expect(calls, <String>['read_org_audit:org-1']);
    });

    test('readOrgAudit maps an empty response to an empty list', () async {
      data['read_org_audit'] = null;

      final List<Map<String, dynamic>> rows = await api.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(rows, isEmpty);
    });

    test('readOrgAudit maps permission denied to the denied kind', () async {
      errors['read_org_audit'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.readOrgAudit(organizationId: 'org-1'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test('listMyMemberships maps a table denial', () async {
      tableErrors['memberships'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.listMyMemberships(userId: 'u-1'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'provider failures expose the fixed user-facing message (A5)',
      () async {
        errors['create_organization'] = const PostgrestException(
          message: 'raw internal provider detail',
        );

        await expectLater(
          api.createOrganization(name: 'New Firm'),
          throwsA(
            isA<SupabaseOrgException>()
                .having((e) => e.kind, 'kind', SupabaseOrgFailureKind.unknown)
                .having((e) => e.message, 'message', orgRequestFailedMessage),
          ),
        );
      },
    );

    test('readOrgAudit falls back to the live zero-arg RPC when the '
        'parameterized signature is missing (A4)', () async {
      int attempts = 0;
      final SupabaseOrgApiImpl fallbackApi = SupabaseOrgApiImpl(
        (String function, Map<String, dynamic> params) async {
          attempts += 1;
          if (attempts == 1) {
            throw const PostgrestException(
              message:
                  'Could not find the function public.read_org_audit'
                  '(p_organization_id) in the schema cache',
              code: 'PGRST202',
            );
          }
          expect(function, 'read_org_audit');
          expect(params, isEmpty);
          return PostgrestResponse<dynamic>(
            data: <dynamic>[
              <String, dynamic>{'id': 1, 'action': 'member_invited'},
            ],
            count: 0,
          );
        },
        (
          String table,
          String columns, {
          String? filterColumn,
          Object? filterValue,
        }) async => <Map<String, dynamic>>[],
      );

      final List<Map<String, dynamic>> rows = await fallbackApi.readOrgAudit(
        organizationId: 'org-1',
      );

      expect(rows, hasLength(1));
      expect(rows.single['action'], 'member_invited');
      expect(attempts, 2);
    });

    test(
      'readOrgAudit does not retry a non-missing-function failure (A4)',
      () async {
        int attempts = 0;
        final SupabaseOrgApiImpl deniedApi = SupabaseOrgApiImpl(
          (String function, Map<String, dynamic> params) async {
            attempts += 1;
            throw const PostgrestException(message: 'permission denied');
          },
          (
            String table,
            String columns, {
            String? filterColumn,
            Object? filterValue,
          }) async => <Map<String, dynamic>>[],
        );

        await expectLater(
          deniedApi.readOrgAudit(organizationId: 'org-1'),
          throwsA(
            isA<SupabaseOrgException>().having(
              (e) => e.kind,
              'kind',
              SupabaseOrgFailureKind.denied,
            ),
          ),
        );
        expect(attempts, 1);
      },
    );

    test('maps a roster denial to the denied kind', () async {
      errors['list_org_members_metadata'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.listMembers(organizationId: 'org-1'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.denied,
          ),
        ),
      );
    });

    test('maps the invalid-name raise', () async {
      errors['create_organization'] = const PostgrestException(
        message: 'organization name is required',
      );

      await expectLater(
        api.createOrganization(name: ' '),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.invalidName,
          ),
        ),
      );
    });

    test(
      'resendInvitation sends the invitation id and returns the token',
      () async {
        data['resend_invitation'] = 'rotated-token';

        final String token = await api.resendInvitation(invitationId: 'inv-7');

        expect(token, 'rotated-token');
        expect(calls, <String>['resend_invitation:inv-7']);
      },
    );

    test('maps the invitation-not-found raise to invalidInvitation', () async {
      errors['resend_invitation'] = const PostgrestException(
        message: 'invitation not found',
      );

      await expectLater(
        api.resendInvitation(invitationId: 'inv-7'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.invalidInvitation,
          ),
        ),
      );
    });

    test('maps the non-pending raise to invalidInvitation', () async {
      errors['revoke_invitation'] = const PostgrestException(
        message: 'only pending invitations can be revoked',
      );

      await expectLater(
        api.revokeInvitation(invitationId: 'inv-7'),
        throwsA(
          isA<SupabaseOrgException>().having(
            (e) => e.kind,
            'kind',
            SupabaseOrgFailureKind.invalidInvitation,
          ),
        ),
      );
    });

    test('deleteMyAccount calls the RPC with no params', () async {
      await api.deleteMyAccount();

      expect(calls, <String>['delete_my_account:']);
    });

    test(
      'acceptInvitation sends the token and returns the membership id',
      () async {
        data['accept_invitation'] = 'membership-3';

        final String id = await api.acceptInvitation(token: 'the-token');

        expect(id, 'membership-3');
        expect(calls, <String>['accept_invitation:the-token']);
      },
    );

    test('maps a transport timeout to providerUnavailable', () async {
      timeouts.add('create_organization');

      await expectLater(
        api.createOrganization(name: 'New Firm'),
        throwsA(
          isA<SupabaseOrgException>()
              .having(
                (e) => e.kind,
                'kind',
                SupabaseOrgFailureKind.providerUnavailable,
              )
              .having((e) => e.message, 'message', orgRequestFailedMessage),
        ),
      );
    });

    test(
      'a void RPC transport timeout is a typed providerUnavailable',
      () async {
        timeouts.add('remove_membership');

        await expectLater(
          api.removeMember(organizationId: 'org-1', userId: 'u-1'),
          throwsA(
            isA<SupabaseOrgException>().having(
              (e) => e.kind,
              'kind',
              SupabaseOrgFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );
  });
}
