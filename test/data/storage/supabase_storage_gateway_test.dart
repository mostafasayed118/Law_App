import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_gateway.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';

/// Hand-rolled fake of the [SupabaseStorageApi] seam: records calls and
/// answers with canned rows or a [SupabaseStorageException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseStorageApi implements SupabaseStorageApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseStorageException? error;

  @override
  Future<List<Map<String, dynamic>>> fetchFiles() async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }
}

Map<String, dynamic> _row({
  String id = 'file-1',
  String matterId = 'm-1',
  String name = 'Demo retainer scan',
  String mimeType = 'application/pdf',
  int sizeBytes = 245760,
  String storagePath = 'org-demo/matter-1/demo-retainer-scan.pdf',
  Object? matters = const <String, dynamic>{'title': 'Demo acquisition review'},
}) => <String, dynamic>{
  'id': id,
  'matter_id': matterId,
  'name': name,
  'mime_type': mimeType,
  'size_bytes': sizeBytes,
  'storage_path': storagePath,
  'matters': matters,
};

void main() {
  late _StubSupabaseStorageApi api;
  late SupabaseStorageGateway gateway;

  setUp(() {
    api = _StubSupabaseStorageApi();
    gateway = SupabaseStorageGateway(api);
  });

  group('row → FileMetadata mapping (D-STR7)', () {
    test(
      'maps a full row to the FileMetadata VO with the embedded matter title',
      () async {
        api.rows = <Map<String, dynamic>>[_row()];

        final Result<List<FileMetadata>> result = await gateway.fetchFiles();

        expect(result.isSuccess, isTrue);
        final FileMetadata file = result.valueOrNull!.single;
        expect(file.id, 'file-1');
        expect(file.name, 'Demo retainer scan');
        expect(file.matterRef, 'Demo acquisition review');
        expect(file.mimeType, 'application/pdf');
        expect(file.sizeBytes, 245760);
        expect(file.storagePath, 'org-demo/matter-1/demo-retainer-scan.pdf');
      },
    );

    test(
      'resolves matterRef from the embedded matters(title) select (D-STR5)',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(
            matterId: 'm-9',
            matters: <String, dynamic>{'title': 'Lease review'},
          ),
        ];

        final FileMetadata file =
            (await gateway.fetchFiles()).valueOrNull!.single;

        expect(file.matterRef, 'Lease review');
      },
    );

    test(
      'falls back to the raw matter id when the embed is absent (D-STR5)',
      () async {
        api.rows = <Map<String, dynamic>>[_row(matters: null)];

        final FileMetadata file =
            (await gateway.fetchFiles()).valueOrNull!.single;

        expect(file.matterRef, 'm-1');
      },
    );

    test(
      'falls back to the raw matter id when the embed title is empty',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(matters: <String, dynamic>{'title': ''}),
        ];

        final FileMetadata file =
            (await gateway.fetchFiles()).valueOrNull!.single;

        expect(file.matterRef, 'm-1');
      },
    );

    test('maps the guarded metadata fields exactly (size/mime/path)', () async {
      api.rows = <Map<String, dynamic>>[
        _row(
          mimeType: 'text/csv',
          sizeBytes: 40960,
          storagePath: 'org-demo/matter-3/demo-evidence-register.csv',
        ),
      ];

      final FileMetadata file =
          (await gateway.fetchFiles()).valueOrNull!.single;

      expect(file.mimeType, 'text/csv');
      expect(file.sizeBytes, 40960);
      expect(file.storagePath, 'org-demo/matter-3/demo-evidence-register.csv');
    });

    test('returns an empty success for no rows', () async {
      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('loud provider-drift handling (no raw TypeErrors)', () {
    test('a non-int size_bytes fails the fetch loudly', () async {
      // bigint → int on PostgREST; a string here is provider drift and must
      // surface as the typed FormatException → AppError, never a raw
      // TypeError across the boundary.
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{..._row(), 'size_bytes': 'big'},
      ];

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'file_read_failed');
    });

    test('a missing name fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'file-1', 'matter_id': 'm-1'},
      ];

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'file_read_failed');
    });

    test('a missing matter_id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'file-1', 'name': 'Demo retainer scan'},
      ];

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'file_read_failed');
    });

    test('a missing storage_path fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'file-1',
          'matter_id': 'm-1',
          'name': 'Demo retainer scan',
          'mime_type': 'application/pdf',
          'size_bytes': 1,
        },
      ];

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'file_read_failed');
    });

    test('a missing id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'matter_id': 'm-1',
          'name': 'Demo retainer scan',
          'mime_type': 'application/pdf',
          'size_bytes': 1,
          'storage_path': 'org-demo/matter-1/x.pdf',
        },
      ];

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'file_read_failed');
    });
  });

  group('failure mapping (contract §5)', () {
    test('maps a denied read to the denied AppError code', () async {
      api.error = const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'file_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseStorageException(
          kind: SupabaseStorageFailureKind.unknown,
          message: 'provider hiccup',
        );

        final Result<List<FileMetadata>> result = await gateway.fetchFiles();

        final AppError error = result.errorOrNull!;
        expect(error.code, 'file_read_failed');
        // The failure path never touches row content (the seam throws before
        // mapping runs) and the AppError context stays empty by construction
        // — only the provider's own message crosses as the technical message.
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.context, isEmpty);
      },
    );

    test('maps an unavailable read to the unavailable AppError code', () async {
      api.error = const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );

      final Result<List<FileMetadata>> result = await gateway.fetchFiles();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'file_read_unavailable');
      expect(error.technicalMessage, 'Provider unavailable.');
    });
  });
}
