import 'package:equatable/equatable.dart';

/// A matter file-metadata row (fourth §14 un-deferral, storage slice D-STR7).
///
/// Carries **non-PII metadata only**: a stable id, a generic demo name, a
/// matter reference, a mime type, a byte size, and the storage path. **There
/// is no content, no bytes, no download URL, and no signed-URL affordance
/// anywhere on the type** (D-STR3/D-STR9) — the metadata-only line is
/// enforced structurally, so the surface can never render file content. The
/// byte-level read is the storage.objects policy + battery's server-side
/// claim (D-STR2); this slice's client shows metadata only. Files come from
/// the fake gateway's fixed synthetic list in env-less runs, and names are
/// static demo copy (R1: fake-data honesty — nothing here may read as a real
/// file).
class FileMetadata extends Equatable {
  const FileMetadata({
    required this.id,
    required this.name,
    required this.matterRef,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
  });

  final String id;

  /// Generic demo wording — never a real client, case, or file reference.
  final String name;

  /// The matter this file belongs to, rendered as one of the existing
  /// synthetic matter titles (the same shape `Document.matterRef` and
  /// `MessageThread.matterRef` use — D-W2/D-MSG4; D-STR5).
  final String matterRef;

  /// The file's declared mime type (e.g. `application/pdf`).
  final String mimeType;

  /// The file's size in bytes (the `files.size_bytes` column, CHECK >= 0).
  final int sizeBytes;

  /// The storage-path key (`{org_id}/{matter_id}/{filename}` per D-STR4) —
  /// the single source of truth linking the metadata row to its object.
  /// Never rendered as a link: the download affordance is a flagged follow-up
  /// (D-STR9).
  final String storagePath;

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    matterRef,
    mimeType,
    sizeBytes,
    storagePath,
  ];
}
