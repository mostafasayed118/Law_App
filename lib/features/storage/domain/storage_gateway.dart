import 'dart:typed_data';

import 'package:legalhub/core/errors/result.dart';
import 'file_metadata.dart';

/// The server's `matter-files` bucket cap (25 MiB).
const int matterFileMaxBytes = 25 * 1024 * 1024;

/// Signed download URL lifetime.
const Duration kSignedUrlTtl = Duration(seconds: 60);

/// MIME types the server bucket accepts for matter files.
const Set<String> matterFileAllowedMimeTypes = <String>{
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
  'text/csv',
  'image/png',
  'image/jpeg',
};

/// File extensions the matter-file picker offers.
const Set<String> matterFileAllowedExtensions = <String>{
  'pdf',
  'doc',
  'docx',
  'txt',
  'csv',
  'png',
  'jpg',
  'jpeg',
};

/// Matter-scoped storage integration boundary (fourth §14 un-deferral,
/// storage slice D-STR7).
///
/// The read path is metadata-only (D-STR3/D-STR9); the write path uploads
/// bytes to the private `matter-files` bucket and registers the metadata row
/// through the audited RPC. Return convention matches the project's [Result]
/// boundary (§D.4) — failures arrive as [Failure] with [AppError], never raw
/// exceptions, and never carry file names or bytes.
abstract interface class StorageGateway {
  /// The caller's assignment-scoped file-metadata list (active member of the
  /// file's org AND assigned on its matter, matrix §4 — the
  /// `files_select_assigned` RLS gate server-side). Deterministic and
  /// read-only.
  ///
  /// [matterId] scopes the read server-side (the workspace passes the open
  /// matter's id); null keeps the caller's full list, so existing callers are
  /// unchanged.
  Future<Result<List<FileMetadata>>> fetchFiles({String? matterId});

  /// Uploads [bytes] for [matterId] and registers the metadata row.
  ///
  /// The server re-derives the matter/org/assignment gate; the returns
  /// [FileMetadata] is the persisted row.
  Future<Result<FileMetadata>> uploadFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required Uint8List bytes,
  });

  /// Creates a short-lived signed URL for [file] (default 60 seconds).
  Future<Result<Uri>> createDownloadUrl(
    FileMetadata file, {
    Duration ttl = kSignedUrlTtl,
  });
}
