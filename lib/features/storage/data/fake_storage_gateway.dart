import 'dart:typed_data';

import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/storage/domain/file_metadata.dart';
import 'package:legalhub/features/storage/domain/storage_gateway.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

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
      matterId: DemoCorpus.matterIds[0],
      name: 'Demo retainer scan',
      matterRef: DemoCorpus.matterTitleAcquisition,
      mimeType: 'application/pdf',
      sizeBytes: 245760,
      storagePath:
          '${DemoCorpus.organizationId}/${DemoCorpus.matterIds[0]}/demo-retainer-scan.pdf',
    ),
    FileMetadata(
      id: 'file-2',
      matterId: DemoCorpus.matterIds[1],
      name: 'Demo lease annex',
      matterRef: DemoCorpus.matterTitleLease,
      mimeType: 'application/pdf',
      sizeBytes: 184320,
      storagePath:
          '${DemoCorpus.organizationId}/${DemoCorpus.matterIds[1]}/demo-lease-annex.pdf',
    ),
    FileMetadata(
      id: 'file-3',
      matterId: DemoCorpus.matterIds[2],
      name: 'Demo evidence register',
      matterRef: DemoCorpus.matterTitleProcedural,
      mimeType: 'text/csv',
      sizeBytes: 40960,
      storagePath:
          '${DemoCorpus.organizationId}/${DemoCorpus.matterIds[2]}/demo-evidence-register.csv',
    ),
    FileMetadata(
      id: 'file-4',
      matterId: DemoCorpus.matterIds[3],
      name: 'Demo correspondence copy',
      matterRef: DemoCorpus.matterTitleFamily,
      mimeType: 'image/png',
      sizeBytes: 512000,
      storagePath:
          '${DemoCorpus.organizationId}/${DemoCorpus.matterIds[3]}/demo-correspondence-copy.png',
    ),
    FileMetadata(
      id: 'file-5',
      matterId: DemoCorpus.matterIds[4],
      name: 'Demo formation checklist',
      matterRef: DemoCorpus.matterTitleStartup,
      mimeType: 'application/msword',
      sizeBytes: 30720,
      storagePath:
          '${DemoCorpus.organizationId}/${DemoCorpus.matterIds[4]}/demo-formation-checklist.doc',
    ),
  ];

  final List<FileMetadata> _uploaded = <FileMetadata>[];
  int _sequence = 0;

  @override
  Future<Result<List<FileMetadata>>> fetchFiles({String? matterId}) async {
    // Metadata only — the synthetic list plus this instance's uploads. A
    // matter id scopes the in-memory read the same way the server-side
    // filter does.
    final List<FileMetadata> rows = <FileMetadata>[
      ...syntheticFiles,
      ..._uploaded,
    ];
    return Result<List<FileMetadata>>.success(
      List<FileMetadata>.unmodifiable(
        matterId == null
            ? rows
            : rows
                  .where((FileMetadata file) => file.matterId == matterId)
                  .toList(growable: false),
      ),
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
      matterId: matterId,
      name: name,
      matterRef: DemoCorpus.matterTitlesById[matterId] ?? matterId,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      storagePath:
          '${DemoCorpus.organizationId}/$matterId/upload-$_sequence-$name',
    );
    _uploaded.add(file);
    return Result<FileMetadata>.success(file);
  }

  @override
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = kSignedUrlTtl,
  }) async {
    return Result<Uri>.success(
      Uri.parse(
        'https://example.com/matter-files/${file.id}'
        '?token=demo&ttl=${ttl.inSeconds}',
      ),
    );
  }
}
