import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/matters/supabase_matter_api.dart';
import 'package:legalhub/data/matters/supabase_matter_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseMatterApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late SupabaseMatterApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      api = SupabaseMatterApiImpl((String table, String columns) async {
        calls.add('$table:$columns');
        final Object? objectError = objectErrors[table];
        if (objectError != null) {
          throw objectError;
        }
        final PostgrestException? error = tableErrors[table];
        if (error != null) {
          throw error;
        }
        return tableData[table] ?? const <Map<String, dynamic>>[];
      });
    });

    test(
      'fetchMatters selects the matters table with the VO columns',
      () async {
        tableData['matters'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'm-1'},
        ];

        final List<Map<String, dynamic>> rows = await api.fetchMatters();

        expect(rows, hasLength(1));
        expect(calls, <String>[
          'matters:id, organization_id, title, practice_area, status, '
              'assigned_attorney_id, created_at',
        ]);
      },
    );

    test('fetchMatters maps a table denial to the denied kind', () async {
      tableErrors['matters'] = const PostgrestException(
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
      tableErrors['matters'] = const PostgrestException(
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
      tableErrors['matters'] = const PostgrestException(
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
        objectErrors['matters'] = Exception('network down');

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
  });
}
