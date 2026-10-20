import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/documents/supabase_document_api.dart';
import 'package:legalhub/data/documents/supabase_document_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseDocumentApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late SupabaseDocumentApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      api = SupabaseDocumentApiImpl((String table, String columns) async {
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
      'fetchDocuments selects the documents table with the VO columns',
      () async {
        tableData['documents'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'doc-1'},
        ];

        final List<Map<String, dynamic>> rows = await api.fetchDocuments();

        expect(rows, hasLength(1));
        expect(calls, <String>[
          'documents:id, matter_id, title, document_type, created_at, '
              'matters(title)',
        ]);
      },
    );

    test('fetchDocuments maps a table denial to the denied kind', () async {
      tableErrors['documents'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchDocuments(),
        throwsA(
          isA<SupabaseDocumentException>().having(
            (e) => e.kind,
            'kind',
            SupabaseDocumentFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchDocuments maps an RLS denial text to the denied kind', () async {
      tableErrors['documents'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.fetchDocuments(),
        throwsA(
          isA<SupabaseDocumentException>().having(
            (e) => e.kind,
            'kind',
            SupabaseDocumentFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'fetchDocuments preserves unknown failures with the message',
      () async {
        tableErrors['documents'] = const PostgrestException(
          message: 'connection reset by peer',
        );

        await expectLater(
          api.fetchDocuments(),
          throwsA(
            isA<SupabaseDocumentException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  SupabaseDocumentFailureKind.unknown,
                )
                .having(
                  (e) => e.message,
                  'message',
                  'connection reset by peer',
                ),
          ),
        );
      },
    );

    test(
      'fetchDocuments maps a non-Postgrest failure to providerUnavailable',
      () async {
        // A transport/network failure is not a PostgrestException; the impl
        // must map it to the typed unavailable kind, never leak a raw
        // exception across the seam (auth-impl defensive-catch precedent).
        objectErrors['documents'] = Exception('network down');

        await expectLater(
          api.fetchDocuments(),
          throwsA(
            isA<SupabaseDocumentException>().having(
              (e) => e.kind,
              'kind',
              SupabaseDocumentFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );

    test('searchDocuments prefilters the documents table on title with the '
        'limit', () async {
      // Same RLS scope, VO columns, and matters(title) embed as the fetch
      // (D-DR1/D-DR2/D-DR4); the only additions are the title ilike column
      // + the page size — the server-side prefilter for unified search
      // (audit: search fan-out).
      final List<String> searchCalls = <String>[];
      final SupabaseDocumentApiImpl searchApi = SupabaseDocumentApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
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

      await searchApi.searchDocuments('letter', limit: 10);

      expect(searchCalls, <String>[
        'documents|id, matter_id, title, document_type, created_at, '
            'matters(title)|title|letter|10',
      ]);
    });

    test('searchDocuments maps a table denial to the denied kind', () async {
      final SupabaseDocumentApiImpl deniedApi = SupabaseDocumentApiImpl(
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
        deniedApi.searchDocuments('letter'),
        throwsA(
          isA<SupabaseDocumentException>().having(
            (e) => e.kind,
            'kind',
            SupabaseDocumentFailureKind.denied,
          ),
        ),
      );
    });
  });
}
