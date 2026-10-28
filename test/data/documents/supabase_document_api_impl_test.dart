import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/documents/data/supabase_document_api.dart';
import 'package:legalhub/features/documents/data/supabase_document_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/supabase_api_stub.dart';

void main() {
  group('SupabaseDocumentApiImpl', () {
    late SupabaseApiStub stub;
    late SupabaseDocumentApiImpl api;

    setUp(() {
      stub = SupabaseApiStub();
      api = SupabaseDocumentApiImpl(stub.tableCaller);
    });

    test(
      'fetchDocuments selects the documents table with the VO columns',
      () async {
        stub.tableData['documents'] = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'doc-1'},
        ];

        final List<Map<String, dynamic>> rows = await api.fetchDocuments();

        expect(rows, hasLength(1));
        expect(stub.calls, <String>[
          'documents:id, matter_id, title, document_type, created_at, '
              'matters(title)',
        ]);
      },
    );

    test(
      'fetchDocuments forwards a non-null matter id to the scoped read',
      () async {
        final List<String> scoped = <String>[];
        final SupabaseDocumentApiImpl scopedApi = SupabaseDocumentApiImpl(
          (String table, String columns) async =>
              const <Map<String, dynamic>>[],
          matterTableCaller:
              (String table, String columns, String matterId) async {
                scoped.add('$table|$matterId');
                return const <Map<String, dynamic>>[];
              },
        );

        await scopedApi.fetchDocuments(matterId: 'matter-1');

        expect(scoped, <String>['documents|matter-1']);
      },
    );

    test('fetchDocuments maps a table denial to the denied kind', () async {
      stub.tableErrors['documents'] = const PostgrestException(
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
      stub.tableErrors['documents'] = const PostgrestException(
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
        stub.tableErrors['documents'] = const PostgrestException(
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
        stub.objectErrors['documents'] = Exception('network down');

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
