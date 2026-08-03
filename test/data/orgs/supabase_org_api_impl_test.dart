import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/orgs/supabase_org_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseOrgApiImpl', () {
    late List<String> calls;
    late Map<String, Object?> data;
    late Map<String, PostgrestException> errors;
    late SupabaseOrgApiImpl api;

    setUp(() {
      calls = <String>[];
      data = <String, Object?>{};
      errors = <String, PostgrestException>{};
      api = SupabaseOrgApiImpl((
        String function,
        Map<String, dynamic> params,
      ) async {
        calls.add('$function:${params.values.join(',')}');
        final PostgrestException? error = errors[function];
        if (error != null) {
          throw error;
        }
        return PostgrestResponse<dynamic>(data: data[function], count: 0);
      });
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
  });
}
