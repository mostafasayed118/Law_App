import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/matters/data/supabase_matter_api.dart';
import 'package:legalhub/features/matters/data/supabase_matter_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/supabase_api_stub.dart';

void main() {
  group('SupabaseMatterApiImpl', () {
    late SupabaseApiStub stub;
    late SupabaseMatterApiImpl api;

    setUp(() {
      stub = SupabaseApiStub();
      api = SupabaseMatterApiImpl(stub.tableCaller);
    });

    test(
      'fetchMatters selects the matters table with the VO columns',
      () async {
        stub.tableData['matters'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'm-1'},
        ];

        final List<Map<String, dynamic>> rows = await api.fetchMatters();

        expect(rows, hasLength(1));
        expect(stub.calls, <String>[
          'matters:id, organization_id, title, practice_area, status, '
              'assigned_attorney_id, created_at',
        ]);
      },
    );

    test('fetchMatters maps a table denial to the denied kind', () async {
      stub.tableErrors['matters'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchMatters maps an RLS denial text to the denied kind', () async {
      stub.tableErrors['matters'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchMatters preserves unknown failures with the message', () async {
      stub.tableErrors['matters'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.fetchMatters(),
        throwsA(
          isA<SupabaseMatterException>()
              .having((e) => e.kind, 'kind', SupabaseMatterFailureKind.unknown)
              .having((e) => e.message, 'message', 'connection reset by peer'),
        ),
      );
    });

    test(
      'fetchMatters maps a non-Postgrest failure to providerUnavailable',
      () async {
        // A transport/network failure is not a PostgrestException; the impl
        // must map it to the typed unavailable kind, never leak a raw
        // exception across the seam (auth-impl defensive-catch precedent).
        stub.objectErrors['matters'] = Exception('network down');

        await expectLater(
          api.fetchMatters(),
          throwsA(
            isA<SupabaseMatterException>().having(
              (e) => e.kind,
              'kind',
              SupabaseMatterFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );

    test(
      'searchMatters prefilters the matters table on title with the limit',
      () async {
        // Same RLS scope and VO columns as the fetch (D-MR1/D-MR4); the only
        // additions are the title ilike column + the page size — the
        // server-side prefilter for unified search (audit: search fan-out).
        final List<String> searchCalls = <String>[];
        final SupabaseMatterApiImpl searchApi = SupabaseMatterApiImpl(
          (String table, String columns) async =>
              const <Map<String, dynamic>>[],
          searchCaller:
              (
                String table,
                String columns,
                String ilikeColumn,
                String needle,
                int limit,
              ) async {
                searchCalls.add('$table|$columns|$ilikeColumn|$needle|$limit');
                return const <Map<String, dynamic>>[];
              },
        );

        await searchApi.searchMatters('acq', limit: 10);

        expect(searchCalls, <String>[
          'matters|id, organization_id, title, practice_area, status, '
              'assigned_attorney_id, created_at|title|acq|10',
        ]);
      },
    );

    test('searchMatters maps a table denial to the denied kind', () async {
      final SupabaseMatterApiImpl deniedApi = SupabaseMatterApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        searchCaller:
            (
              String table,
              String columns,
              String ilikeColumn,
              String needle,
              int limit,
            ) async {
              throw const PostgrestException(message: 'permission denied');
            },
      );

      await expectLater(
        deniedApi.searchMatters('acq'),
        throwsA(
          isA<SupabaseMatterException>().having(
            (e) => e.kind,
            'kind',
            SupabaseMatterFailureKind.denied,
          ),
        ),
      );
    });
  });
}
