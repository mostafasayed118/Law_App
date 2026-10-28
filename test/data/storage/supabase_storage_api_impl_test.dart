import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/supabase_api_stub.dart';

void main() {
  group('SupabaseStorageApiImpl', () {
    late SupabaseApiStub stub;
    late SupabaseStorageApiImpl api;

    setUp(() {
      stub = SupabaseApiStub();
      api = SupabaseStorageApiImpl(stub.tableCaller);
    });

    test('fetchFiles selects the files table with the VO columns', () async {
      stub.tableData['files'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'file-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchFiles();

      expect(rows, hasLength(1));
      expect(stub.calls, <String>[
        'files:id, matter_id, name, mime_type, size_bytes, storage_path, '
            'matters(title)',
      ]);
    });

    test('fetchFiles maps a table denial to the denied kind', () async {
      stub.tableErrors['files'] = const PostgrestException(
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
      stub.tableErrors['files'] = const PostgrestException(
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
      stub.tableErrors['files'] = const PostgrestException(
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
        stub.objectErrors['files'] = Exception('network down');

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

  group('SupabaseStorageApiImpl write seam', () {
    late List<String> calls;
    late List<String> paths;
    late List<String> functions;
    late List<Map<String, dynamic>> params;
    late Uint8List uploadedBytes;
    late String uploadedContentType;
    late SupabaseStorageApiImpl api;

    setUp(() {
      calls = <String>[];
      paths = <String>[];
      functions = <String>[];
      params = <Map<String, dynamic>>[];
      uploadedBytes = Uint8List(0);
      uploadedContentType = '';
      api = SupabaseStorageApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        matterCaller: (String matterId) async {
          calls.add('matter:$matterId');
          return <String, dynamic>{'id': matterId};
        },
        objectUploader:
            (String path, Uint8List bytes, String contentType) async {
              paths.add(path);
              uploadedBytes = bytes;
              uploadedContentType = contentType;
            },
        signedUrlCreator: (String path, int expiresInSeconds) async {
          calls.add('sign:$path:$expiresInSeconds');
          return 'https://example.supabase.co/storage/v1/object/sign/'
              'matter-files/$path?token=demo';
        },
        objectRemover: (String path) async => paths.add('remove:$path'),
        rpcCaller: (String function, Map<String, dynamic> namedParams) async {
          functions.add(function);
          params.add(namedParams);
          return <String, dynamic>{
            'file': <String, dynamic>{'id': 'file-1'},
            'matter_title': 'Demo matter',
          };
        },
      );
    });

    test('fetchMatterForUpload forwards the matter id', () async {
      final Map<String, dynamic> row = await api.fetchMatterForUpload('m-1');

      expect(row['id'], 'm-1');
      expect(calls, <String>['matter:m-1']);
    });

    test('uploadObject forwards the path, bytes, and content type', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

      await api.uploadObject('org-1/m-1/file.pdf', bytes, 'application/pdf');

      expect(paths, <String>['org-1/m-1/file.pdf']);
      expect(uploadedBytes, bytes);
      expect(uploadedContentType, 'application/pdf');
    });

    test('createSignedUrl forwards the path and TTL', () async {
      final String url = await api.createSignedUrl('org-1/m-1/file.pdf', 120);

      expect(calls, <String>['sign:org-1/m-1/file.pdf:120']);
      expect(url, startsWith('https://'));
    });

    test('removeObject forwards the path', () async {
      await api.removeObject('org-1/m-1/file.pdf');

      expect(paths, <String>['remove:org-1/m-1/file.pdf']);
    });

    test('registerMatterFile sends the exact RPC params', () async {
      final Map<String, dynamic> response = await api.registerMatterFile(
        matterId: 'm-1',
        name: 'brief.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 12,
        storagePath: 'org-1/m-1/123-brief.pdf',
      );

      expect(functions, <String>['register_matter_file']);
      expect(params.single, <String, dynamic>{
        'p_matter_id': 'm-1',
        'p_name': 'brief.pdf',
        'p_mime_type': 'application/pdf',
        'p_size_bytes': 12,
        'p_storage_path': 'org-1/m-1/123-brief.pdf',
      });
      expect(response['matter_title'], 'Demo matter');
    });

    test('registerMatterFile maps a non-map RPC payload to unknown', () async {
      final SupabaseStorageApiImpl nonMapApi = SupabaseStorageApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        rpcCaller: (String function, Map<String, dynamic> namedParams) async =>
            <Object?>[],
      );

      await expectLater(
        nonMapApi.registerMatterFile(
          matterId: 'm-1',
          name: 'brief.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 12,
          storagePath: 'org-1/m-1/123-brief.pdf',
        ),
        throwsA(
          isA<SupabaseStorageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.unknown,
          ),
        ),
      );
    });

    test('registerMatterFile maps a Postgrest denial to denied', () async {
      final SupabaseStorageApiImpl deniedApi = SupabaseStorageApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        rpcCaller: (String function, Map<String, dynamic> namedParams) async {
          throw const PostgrestException(message: 'permission denied');
        },
      );

      await expectLater(
        deniedApi.registerMatterFile(
          matterId: 'm-1',
          name: 'brief.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 12,
          storagePath: 'org-1/m-1/123-brief.pdf',
        ),
        throwsA(
          isA<SupabaseStorageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.denied,
          ),
        ),
      );
    });

    test('uploadObject maps storage statuses to typed kinds', () async {
      const Map<String?, SupabaseStorageFailureKind> cases =
          <String?, SupabaseStorageFailureKind>{
            '413': SupabaseStorageFailureKind.tooLarge,
            '415': SupabaseStorageFailureKind.unsupportedType,
            '403': SupabaseStorageFailureKind.denied,
            '404': SupabaseStorageFailureKind.notFound,
            '409': SupabaseStorageFailureKind.conflict,
            null: SupabaseStorageFailureKind.providerUnavailable,
            '500': SupabaseStorageFailureKind.unknown,
          };

      for (final MapEntry<String?, SupabaseStorageFailureKind> entry
          in cases.entries) {
        final SupabaseStorageApiImpl failingApi = SupabaseStorageApiImpl(
          (String table, String columns) async =>
              const <Map<String, dynamic>>[],
          objectUploader:
              (String path, Uint8List bytes, String contentType) async {
                throw StorageException('upload failed', statusCode: entry.key);
              },
        );

        await expectLater(
          failingApi.uploadObject(
            'org-1/m-1/file.pdf',
            Uint8List(0),
            'application/pdf',
          ),
          throwsA(
            isA<SupabaseStorageException>().having(
              (e) => e.kind,
              'kind',
              entry.value,
            ),
          ),
          reason: 'status ${entry.key}',
        );
      }
    });

    test('uploadObject maps a transport failure to unavailable', () async {
      final SupabaseStorageApiImpl transportApi = SupabaseStorageApiImpl(
        (String table, String columns) async => const <Map<String, dynamic>>[],
        objectUploader:
            (String path, Uint8List bytes, String contentType) async {
              throw Exception('socket closed');
            },
      );

      await expectLater(
        transportApi.uploadObject(
          'org-1/m-1/file.pdf',
          Uint8List(0),
          'application/pdf',
        ),
        throwsA(
          isA<SupabaseStorageException>().having(
            (e) => e.kind,
            'kind',
            SupabaseStorageFailureKind.providerUnavailable,
          ),
        ),
      );
    });
  });
}
