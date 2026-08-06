import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api.dart';
import 'package:legalhub/data/admin/supabase_platform_admin_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabasePlatformAdminApiImpl', () {
    late List<String> calls;
    late Map<String, Object?> data;
    late Map<String, PostgrestException> errors;
    late SupabasePlatformAdminApiImpl api;

    setUp(() {
      calls = <String>[];
      data = <String, Object?>{};
      errors = <String, PostgrestException>{};
      api = SupabasePlatformAdminApiImpl((
        String function,
        Map<String, dynamic> params,
      ) async {
        calls.add(
          params.isEmpty ? function : '$function:${params.values.join(',')}',
        );
        final PostgrestException? error = errors[function];
        if (error != null) {
          throw error;
        }
        return PostgrestResponse<dynamic>(data: data[function], count: 0);
      });
    });

    test('listOrganizations calls the RPC with no params', () async {
      data['list_organizations_metadata'] = <dynamic>[
        <String, dynamic>{'organization_id': 'org-1'},
        'not-a-map',
      ];

      final List<Map<String, dynamic>> rows = await api.listOrganizations();

      expect(rows, hasLength(1));
      expect(calls, <String>['list_organizations_metadata']);
    });

    test('listMembers calls the RPC with no params', () async {
      data['list_members_metadata'] = <dynamic>[
        <String, dynamic>{'user_id': 'u-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.listMembers();

      expect(rows, hasLength(1));
      expect(calls, <String>['list_members_metadata']);
    });

    test('maps a non-owner denial to the denied kind', () async {
      errors['list_organizations_metadata'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.listOrganizations(),
        throwsA(
          isA<SupabasePlatformAdminException>().having(
            (e) => e.kind,
            'kind',
            SupabasePlatformAdminFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'suspendMembership sends org + user to suspend_membership_platform',
      () async {
        await api.suspendMembership(organizationId: 'org-1', userId: 'u-2');

        expect(calls, <String>['suspend_membership_platform:org-1,u-2']);
      },
    );

    test(
      'reactivateMembership sends org + user to reactivate_membership_platform',
      () async {
        await api.reactivateMembership(organizationId: 'org-1', userId: 'u-2');

        expect(calls, <String>['reactivate_membership_platform:org-1,u-2']);
      },
    );

    test('deleteDemoAccount sends the user id', () async {
      await api.deleteDemoAccount(userId: 'u-9');

      expect(calls, <String>['delete_demo_account:u-9']);
    });

    test('maps the never-self raise to denied', () async {
      errors['delete_demo_account'] = const PostgrestException(
        message: 'cannot delete your own account via this path',
      );

      await expectLater(
        api.deleteDemoAccount(userId: 'u-9'),
        throwsA(
          isA<SupabasePlatformAdminException>().having(
            (e) => e.kind,
            'kind',
            SupabasePlatformAdminFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'maps an unspecified raise to unknown with the message preserved',
      () async {
        errors['list_members_metadata'] = const PostgrestException(
          message: 'provider hiccup',
        );

        await expectLater(
          api.listMembers(),
          throwsA(
            isA<SupabasePlatformAdminException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  SupabasePlatformAdminFailureKind.unknown,
                )
                .having((e) => e.message, 'message', 'provider hiccup'),
          ),
        );
      },
    );
  });
}
