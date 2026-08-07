import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseStorageApiImpl', () {
    late List<String> calls;
    late Map<String, List<Map<String, dynamic>>> tableData;
    late Map<String, PostgrestException> tableErrors;
    late Map<String, Object> objectErrors;
    late SupabaseStorageApiImpl api;

    setUp(() {
      calls = <String>[];
      tableData = <String, List<Map<String, dynamic>>>{};
      tableErrors = <String, PostgrestException>{};
      objectErrors = <String, Object>{};
      api = SupabaseStorageApiImpl((String table, String columns) async {
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

    test('fetchFiles selects the files table with the VO columns', () async {
      tableData['files'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'file-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchFiles();

      expect(rows, hasLength(1));
      expect(calls, <String>[
        'files:id, matter_id, name, mime_type, size_bytes, storage_path, '
            'matters(title)',
      ]);
    });

    test('fetchFiles maps a table denial to the denied kind', () async {
      tableErrors['files'] = const PostgrestException(
        message: 'permission denied',
      );

      await expectLater(
        api.fetchFiles(),
        throwsA(
          isA<SupabaseStorageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchFiles maps an RLS denial text to the denied kind', () async {
      tableErrors['files'] = const PostgrestException(
        message: 'new row violates row-level security policy',
      );

      await expectLater(
        api.fetchFiles(),
        throwsA(
          isA<SupabaseStorageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.denied,
          ),
        ),
      );
    });

    test('fetchFiles preserves unknown failures with the message', () async {
      tableErrors['files'] = const PostgrestException(
        message: 'connection reset by peer',
      );

      await expectLater(
        api.fetchFiles(),
        throwsA(
          isA<SupabaseStorageException>()
              .having((e) => e.kind, 'kind', SupabaseStorageFailureKind.unknown)
              .having((e) => e.message, 'message', 'connection reset by peer'),
        ),
      );
    });

    test(
      'fetchFiles maps a non-Postgrest failure to providerUnavailable',
      () async {
        // A transport/network failure is not a PostgrestException; the impl
        // must map it to the typed unavailable kind, never leak a raw
        // exception across the seam (auth-impl defensive-catch precedent).
        objectErrors['files'] = Exception('network down');

        await expectLater(
          api.fetchFiles(),
          throwsA(
            isA<SupabaseStorageException>().having(
              (e) => e.kind,
              'kind',
              SupabaseStorageFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );
  });
}
