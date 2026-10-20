import 'dart:typed_data';

import '../../../core/errors/result.dart';
import '../domain/file_metadata.dart';
import '../domain/storage_gateway.dart';

/// Development-only storage implementation: a fixed synthetic list of
/// non-PII file **metadata** plus deterministic in-memory uploads.
///
/// [fetchFiles] returns the synthetic list followed by any uploads made in
/// this instance — no real backend, no storage bytes, no PII. Uploads add a
/// metadata row only (the bytes argument is ignored); [createDownloadUrl]
/// returns a deterministic https URL. The list resolves immediately (no
/// artificial delay) so cubit/widget tests stay timing-independent.
class FakeStorageGateway implements StorageGateway {
  /// The fixed synthetic file-metadata list served by [fetchFiles].
  static final List<FileMetadata> syntheticFiles = <FileMetadata>[
    FileMetadata(
      id: 'file-1',
      name: 'Demo retainer scan',
      matterRef: 'Demo acquisition review',
      mimeType: 'application/pdf',
      sizeBytes: 245760,
      storagePath: 'org-demo/matter-1/demo-retainer-scan.pdf',
    ),
    FileMetadata(
      id: 'file-2',
      name: 'Demo lease annex',
      matterRef: 'Commercial lease consultation',
      mimeType: 'application/pdf',
      sizeBytes: 184320,
      storagePath: 'org-demo/matter-2/demo-lease-annex.pdf',
    ),
    FileMetadata(
      id: 'file-3',
      name: 'Demo evidence register',
      matterRef: 'Procedural review matter',
      mimeType: 'text/csv',
      sizeBytes: 40960,
      storagePath: 'org-demo/matter-3/demo-evidence-register.csv',
    ),
    FileMetadata(
      id: 'file-4',
      name: 'Demo correspondence copy',
      matterRef: 'Family status consultation',
      mimeType: 'image/png',
      sizeBytes: 512000,
      storagePath: 'org-demo/matter-4/demo-correspondence-copy.png',
    ),
    FileMetadata(
      id: 'file-5',
      name: 'Demo formation checklist',
      matterRef: 'Startup formation advisory',
      mimeType: 'application/msword',
      sizeBytes: 30720,
      storagePath: 'org-demo/matter-5/demo-formation-checklist.doc',
    ),
  ];

  /// Maps the synthetic matter ids used by tests to their demo titles.
  static const Map<String, String> syntheticMatterTitles = <String, String>{
    'matter-1': 'Demo acquisition review',
    'matter-2': 'Commercial lease consultation',
    'matter-3': 'Procedural review matter',
    'matter-4': 'Family status consultation',
    'matter-5': 'Startup formation advisory',
  };

  final List<FileMetadata> _uploaded = <FileMetadata>[];
  int _sequence = 0;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles() async {
    // Metadata only — the synthetic list plus this instance's uploads.
    return Result<List<FileMetadata>>.success(
      List<FileMetadata>.unmodifiable(<FileMetadata>[
        ...syntheticFiles,
        ..._uploaded,
      ]),
    );
  }

  @override
  Future<Result<FileMetadata>> uploadFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required Uint8List bytes,
  }) async {
    _sequence += 1;
    final FileMetadata file = FileMetadata(
      id: 'upload-$_sequence',
      name: name,
      matterRef: syntheticMatterTitles[matterId] ?? matterId,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      storagePath: 'org-demo/$matterId/upload-$_sequence-$name',
    );
    _uploaded.add(file);
    return Result<FileMetadata>.success(file);
  }

  @override
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    return Result<Uri>.success(
      Uri.parse(
        'https://example.com/matter-files/${file.id}'
        '?token=demo&ttl=${ttl.inSeconds}',
      ),
    );
  }
}
