import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/storage/supabase_storage_api.dart';
import 'package:legalhub/data/storage/supabase_storage_gateway.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';

/// Hand-rolled fake of the [SupabaseStorageApi] seam: records calls and
/// answers with canned rows or a [SupabaseStorageException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseStorageApi implements SupabaseStorageApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseStorageException? error;

  Map<String, dynamic> matter = <String, dynamic>{};
  SupabaseStorageException? matterError;

  final List<String> uploadedPaths = <String>[];
  Uint8List? uploadedBytes;
  String? uploadedContentType;
  SupabaseStorageException? uploadError;

  final List<String> removedPaths = <String>[];
  SupabaseStorageException? removeError;

  String signedUrl =
      'https://example.supabase.co/storage/v1/object/sign/matter-files/demo'
      '?token=demo';
  String? signedPath;
  int? signedTtl;
  SupabaseStorageException? signedUrlError;

  Map<String, dynamic> registerResponse = <String, dynamic>{};
  Map<String, dynamic>? registerParams;
  SupabaseStorageException? registerError;

  @override
  Future<List<Map<String, dynamic>>> fetchFiles({String? matterId}) async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }

  @override
  Future<Map<String, dynamic>> fetchMatterForUpload(String matterId) async {
    if (matterError != null) {
      throw matterError!;
    }
    return matter;
  }

  @override
  Future<void> uploadObject(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    if (uploadError != null) {
      throw uploadError!;
    }
    uploadedPaths.add(path);
    uploadedBytes = bytes;
    uploadedContentType = contentType;
  }

  @override
  Future<String> createSignedUrl(String path, int expiresInSeconds) async {
    if (signedUrlError != null) {
      throw signedUrlError!;
    }
    signedPath = path;
    signedTtl = expiresInSeconds;
    return signedUrl;
  }

  @override
  Future<void> removeObject(String path) async {
    if (removeError != null) {
      throw removeError!;
    }
    removedPaths.add(path);
  }

  @override
  Future<Map<String, dynamic>> registerMatterFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required String storagePath,
  }) async {
    if (registerError != null) {
      throw registerError!;
    }
    registerParams = <String, dynamic>{
      'matterId': matterId,
      'name': name,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'storagePath': storagePath,
    };
    return registerResponse;
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

  group('uploadFile orchestration', () {
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);

    setUp(() {
      api.matter = <String, dynamic>{
        'id': 'm-1',
        'organization_id': 'org-1',
        'title': 'Lease review',
      };
      api.registerResponse = <String, dynamic>{
        'file': _row(
          id: 'file-9',
          matterId: 'm-1',
          name: 'brief.pdf',
          sizeBytes: 3,
          storagePath: 'org-1/m-1/123-brief.pdf',
        ),
        'matter_title': 'Lease review',
      };
    });

    test(
      'uploads under the org/matter prefix and maps the registered row',
      () async {
        final Result<FileMetadata> result = await gateway.uploadFile(
          matterId: 'm-1',
          name: 'My brief..pdf',
          mimeType: 'application/pdf',
          sizeBytes: 3,
          bytes: bytes,
        );

        expect(result.isSuccess, isTrue);
        final FileMetadata file = result.valueOrNull!;
        expect(file.id, 'file-9');
        expect(file.name, 'brief.pdf');
        expect(file.matterRef, 'Lease review');
        expect(file.sizeBytes, 3);

        expect(api.uploadedPaths, hasLength(1));
        expect(
          api.uploadedPaths.single,
          matches(RegExp(r'^org-1/m-1/\d+-My_brief\.pdf$')),
        );
        expect(api.uploadedBytes, bytes);
        expect(api.uploadedContentType, 'application/pdf');
        expect(api.registerParams, <String, dynamic>{
          'matterId': 'm-1',
          'name': 'My brief..pdf',
          'mimeType': 'application/pdf',
          'sizeBytes': 3,
          'storagePath': api.uploadedPaths.single,
        });
        expect(api.removedPaths, isEmpty);
      },
    );

    test('an unreadable matter is a denial with no upload', () async {
      api.matter = <String, dynamic>{};

      final Result<FileMetadata> result = await gateway.uploadFile(
        matterId: 'm-1',
        name: 'brief.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 3,
        bytes: bytes,
      );

      expect(result.errorOrNull?.code, 'file_upload_denied');
      expect(api.uploadedPaths, isEmpty);
    });

    test('an oversize file fails before the bucket call', () async {
      final Result<FileMetadata> result = await gateway.uploadFile(
        matterId: 'm-1',
        name: 'huge.pdf',
        mimeType: 'application/pdf',
        sizeBytes: matterFileMaxBytes + 1,
        bytes: bytes,
      );

      expect(result.errorOrNull?.code, 'file_upload_too_large');
      expect(api.uploadedPaths, isEmpty);
    });

    test('an unsupported MIME type fails before the bucket call', () async {
      final Result<FileMetadata> result = await gateway.uploadFile(
        matterId: 'm-1',
        name: 'archive.zip',
        mimeType: 'application/zip',
        sizeBytes: 3,
        bytes: bytes,
      );

      expect(result.errorOrNull?.code, 'file_upload_unsupported_type');
      expect(api.uploadedPaths, isEmpty);
    });

    test('a registration failure removes the uploaded object and keeps the '
        'original failure', () async {
      api.registerError = const SupabaseStorageException(
        kind: SupabaseStorageFailureKind.conflict,
        message: 'object org-1/m-1/secret-brief.pdf already exists',
      );

      final Result<FileMetadata> result = await gateway.uploadFile(
        matterId: 'm-1',
        name: 'secret-brief.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 3,
        bytes: bytes,
      );

      final AppError error = result.errorOrNull!;
      expect(error.code, 'file_upload_conflict');
      expect(api.removedPaths, <String>[api.uploadedPaths.single]);
      // Redaction: the provider message can echo the object path, so neither
      // the file name nor the path may cross into the AppError.
      expect(error.technicalMessage, isNot(contains('secret-brief.pdf')));
      expect(error.technicalMessage, isNot(contains('org-1/m-1')));
    });

    test('maps upload statuses to the typed codes', () async {
      const Map<SupabaseStorageFailureKind, String> codes =
          <SupabaseStorageFailureKind, String>{
            SupabaseStorageFailureKind.denied: 'file_upload_denied',
            SupabaseStorageFailureKind.tooLarge: 'file_upload_too_large',
            SupabaseStorageFailureKind.unsupportedType:
                'file_upload_unsupported_type',
            SupabaseStorageFailureKind.conflict: 'file_upload_conflict',
            SupabaseStorageFailureKind.providerUnavailable:
                'file_upload_unavailable',
            SupabaseStorageFailureKind.notFound: 'file_upload_failed',
            SupabaseStorageFailureKind.unknown: 'file_upload_failed',
          };

      for (final MapEntry<SupabaseStorageFailureKind, String> entry
          in codes.entries) {
        api.uploadError = SupabaseStorageException(
          kind: entry.key,
          message: 'provider said no to org-1/m-1/secret.pdf',
        );
        api.uploadedPaths.clear();

        final Result<FileMetadata> result = await gateway.uploadFile(
          matterId: 'm-1',
          name: 'secret.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 3,
          bytes: bytes,
        );

        expect(result.errorOrNull?.code, entry.value, reason: entry.key.name);
        expect(
          result.errorOrNull?.technicalMessage,
          isNot(contains('secret.pdf')),
          reason: entry.key.name,
        );
      }
    });
  });

  group('createDownloadUrl', () {
    final FileMetadata file = _rowFile();

    test('signs the storage path with the requested TTL', () async {
      final Result<Uri> result = await gateway.createDownloadUrl(
        file,
        ttl: const Duration(seconds: 120),
      );

      expect(result.isSuccess, isTrue);
      expect(api.signedPath, file.storagePath);
      expect(api.signedTtl, 120);
      expect(result.valueOrNull?.scheme, 'https');
    });

    test('rejects a non-https signed URL', () async {
      api.signedUrl = 'http://example.supabase.co/object/sign/file.pdf';

      final Result<Uri> result = await gateway.createDownloadUrl(file);

      expect(result.errorOrNull?.code, 'file_open_failed');
    });

    test(
      'maps a denial and unavailable failure without provider text',
      () async {
        api.signedUrlError = const SupabaseStorageException(
          kind: SupabaseStorageFailureKind.denied,
          message: 'permission denied for org-1/m-1/secret.pdf',
        );

        final Result<Uri> denied = await gateway.createDownloadUrl(file);
        expect(denied.errorOrNull?.code, 'file_open_denied');
        expect(
          denied.errorOrNull?.technicalMessage,
          isNot(contains('secret.pdf')),
        );

        api.signedUrlError = const SupabaseStorageException(
          kind: SupabaseStorageFailureKind.providerUnavailable,
          message: 'connection reset',
        );

        final Result<Uri> unavailable = await gateway.createDownloadUrl(file);
        expect(unavailable.errorOrNull?.code, 'file_open_unavailable');
        expect(unavailable.errorOrNull?.kind, AppErrorKind.unavailable);
      },
    );
  });
}

FileMetadata _rowFile() {
  return const FileMetadata(
    id: 'file-1',
    name: 'Demo retainer scan',
    matterRef: 'Demo acquisition review',
    mimeType: 'application/pdf',
    sizeBytes: 245760,
    storagePath: 'org-demo/matter-1/demo-retainer-scan.pdf',
  );
}
