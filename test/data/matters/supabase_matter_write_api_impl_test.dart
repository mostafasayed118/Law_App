import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/matters/supabase_matter_write_api.dart';
import 'package:legalhub/data/matters/supabase_matter_write_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseMatterWriteApiImpl', () {
    late List<String> rpcCalls;
    late Map<String, Object?> rpcData;
    late Map<String, PostgrestException> rpcErrors;
    late SupabaseMatterWriteApiImpl api;

    setUp(() {
      rpcCalls = <String>[];
      rpcData = <String, Object?>{};
      rpcErrors = <String, PostgrestException>{};
      api = SupabaseMatterWriteApiImpl(
        rpcCaller: (String function, Map<String, dynamic> params) async {
          // The recorded shape pins the RPC contract: function name + the
          // named params (p_organization_id, p_title, p_practice_area,
          // p_assigned_client_id, p_assigned_attorney_id) and their values.
          rpcCalls.add(
            '$function:${params.keys.join(',')}:${params.values.join(',')}',
          );
          final PostgrestException? error = rpcErrors[function];
          if (error != null) {
            throw error;
          }
          return PostgrestResponse<dynamic>(data: rpcData[function], count: 0);
        },
      );
    });

    test(
      'calls create_matter with the RPC\'s exact parameter names (C-D4)',
      () async {
        rpcData['create_matter'] = 'd28f1f05-f95f-46ea-9b15-767f15778c01';

        final String id = await api.createMatter(
          organizationId: 'org-demo',
          title: '  Demo acquisition review  ',
          practiceArea: 'corporate',
          assignedClientId: 'client-a',
          assignedAttorneyId: 'attorney-a',
        );

        // The params use the EXACT RPC names (p_*), the title is trimmed, and
        // the practice area is the enum-name the 04 CHECK accepts.
        expect(rpcCalls, <String>[
          'create_matter:p_organization_id,p_title,p_practice_area,'
              'p_assigned_client_id,p_assigned_attorney_id:'
              'org-demo,Demo acquisition review,corporate,client-a,attorney-a',
        ]);
        expect(id, 'd28f1f05-f95f-46ea-9b15-767f15778c01');
      },
    );

    test(
      'sends null assignees as null (orphan creates allowed, F2-D5)',
      () async {
        rpcData['create_matter'] = 'matter-1';

        await api.createMatter(
          organizationId: 'org-demo',
          title: 'Demo matter',
          practiceArea: 'civil',
        );

        expect(rpcCalls, <String>[
          'create_matter:p_organization_id,p_title,p_practice_area,'
              'p_assigned_client_id,p_assigned_attorney_id:'
              'org-demo,Demo matter,civil,null,null',
        ]);
      },
    );

    test('maps the F2-D2 owner refusal to the ownerForbidden kind', () async {
      rpcErrors['create_matter'] = const PostgrestException(
        message: 'platform owner cannot be assigned to a matter',
      );

      await expectLater(
        api.createMatter(
          organizationId: 'org-demo',
          title: 'Demo matter',
          practiceArea: 'civil',
        ),
        throwsA(
          isA<SupabaseMatterWriteException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterWriteFailureKind.ownerForbidden,
          ),
        ),
      );
    });

    test(
      'maps the F2-D4 member refusals to the assigneeInvalid kind',
      () async {
        rpcErrors['create_matter'] = const PostgrestException(
          message:
              'assigned client must be an active member of the organization',
        );

        await expectLater(
          api.createMatter(
            organizationId: 'org-demo',
            title: 'Demo matter',
            practiceArea: 'civil',
          ),
          throwsA(
            isA<SupabaseMatterWriteException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMatterWriteFailureKind.assigneeInvalid,
            ),
          ),
        );
      },
    );

    test('maps the title validation to the validation kind', () async {
      rpcErrors['create_matter'] = const PostgrestException(
        message: 'matter title is required',
      );

      await expectLater(
        api.createMatter(
          organizationId: 'org-demo',
          title: 'Demo matter',
          practiceArea: 'civil',
        ),
        throwsA(
          isA<SupabaseMatterWriteException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterWriteFailureKind.validation,
          ),
        ),
      );
    });

    test('maps the F2-D1 denial to the denied kind', () async {
      rpcErrors['create_matter'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.createMatter(
          organizationId: 'org-demo',
          title: 'Demo matter',
          practiceArea: 'civil',
        ),
        throwsA(
          isA<SupabaseMatterWriteException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterWriteFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'maps a non-Postgrest provider failure to providerUnavailable',
      () async {
        rpcErrors['create_matter'] = const PostgrestException(
          message: 'some unknown failure',
        );

        await expectLater(
          api.createMatter(
            organizationId: 'org-demo',
            title: 'Demo matter',
            practiceArea: 'civil',
          ),
          throwsA(
            isA<SupabaseMatterWriteException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMatterWriteFailureKind.unknown,
            ),
          ),
        );
      },
    );

    test('surfaces a returned non-id as a typed unknown', () async {
      rpcData['create_matter'] = 42;

      await expectLater(
        api.createMatter(
          organizationId: 'org-demo',
          title: 'Demo matter',
          practiceArea: 'civil',
        ),
        throwsA(
          isA<SupabaseMatterWriteException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterWriteFailureKind.unknown,
          ),
        ),
      );
    });
  });
}
