import '../../../core/errors/result.dart';
import '../domain/file_metadata.dart';
import '../domain/storage_gateway.dart';

/// Development-only storage implementation: a fixed synthetic list of
/// non-PII file **metadata**.
///
/// No real backend, no storage bytes, no download affordance (D-STR7/
/// D-STR9): [fetchFiles] returns the same deterministic list on every call.
/// Files carry id / generic demo name / matter reference (one of the known
/// synthetic matter titles, D-W2/D-STR5) / mime type / byte size / storage
/// path only — **no content, no bytes, no download URL, no client or
/// real-looking file references**, and names are static demo copy that must
/// never read as a real file (R1). The storage path uses the D-STR4
/// `{org}/{matter}/{filename}` encoding with clearly-demo segments. The list
/// resolves immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
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

  @override
  Future<Result<List<FileMetadata>>> fetchFiles() async {
    // Metadata only — the synthetic list is returned as-is; nothing crosses
    // this boundary but the D-STR3 metadata surface.
    return Result<List<FileMetadata>>.success(syntheticFiles);
  }
}
