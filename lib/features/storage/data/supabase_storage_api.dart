/// Provider-neutral files/bucket seam.
///
/// The seam is the only surface the storage gateway talks to: plain map rows
/// out, typed [SupabaseStorageException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseDocumentApi]).
library;

import 'dart:typed_data';

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `DocumentTableCaller` from the
/// documents seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef StorageTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// A server-side matter-scoped SELECT: table + columns + matter id → raw map
/// rows.
///
/// Separate callable (rather than widening [StorageTableCaller]) so existing
/// test injections of the two-arg fetch shape keep compiling.
typedef StorageMatterTableCaller =
    Future<List<Map<String, dynamic>>> Function(
      String table,
      String columns,
      String matterId,
    );

/// The RLS-scoped matter lookup for an upload (id, organization_id, title).
typedef StorageMatterCaller =
    Future<Map<String, dynamic>> Function(String matterId);

/// Uploads bytes to the `matter-files` bucket at [path].
typedef StorageObjectUploader =
    Future<void> Function(String path, Uint8List bytes, String contentType);

/// Creates a signed URL for [path] valid for [expiresInSeconds].
typedef StorageSignedUrlCreator =
    Future<String> Function(String path, int expiresInSeconds);

/// Removes an object from the `matter-files` bucket.
typedef StorageObjectRemover = Future<void> Function(String path);

/// A raw RPC call: function name + named params → decoded payload.
typedef StorageRpcCaller =
    Future<Object?> Function(String function, Map<String, dynamic> params);

/// Typed reasons the storage surface can fail, mapped from the provider.
enum SupabaseStorageFailureKind {
  /// The caller is not permitted (RLS denied, 403, or no session).
  denied,

  /// The object exceeds the bucket's size limit (413).
  tooLarge,

  /// The object's MIME type is not allowed (415).
  unsupportedType,

  /// The object or row does not exist (404).
  notFound,

  /// The object already exists / conflicts (409).
  conflict,

  /// The provider is unavailable or rate-limited (no status / transport).
  providerUnavailable,

  /// An unspecified failure, including an RPC that returned a non-map.
  unknown,
}

/// A typed failure crossing the [SupabaseStorageApi] seam.
class SupabaseStorageException implements Exception {
  const SupabaseStorageException({required this.kind, required this.message});

  final SupabaseStorageFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseStorageException(${kind.name}): $message';
}

/// Files/bucket surface backed by Supabase PostgREST + Storage.
///
/// The SELECT is RLS-scoped (plan D-STR1/D-STR2); the write path is the
/// two-step contract: upload the object under the matter prefix, then call
/// `register_matter_file` to persist the metadata row.
abstract interface class SupabaseStorageApi {
  /// The caller's assignment-scoped `files` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `name`, `mime_type`,
  /// `size_bytes`, `storage_path`, `matters(title)` — the metadata-only read
  /// surface the [FileMetadata] VO needs (D-STR3: no content/body/url column
  /// exists).
  ///
  /// When [matterId] is present the SELECT is additionally filtered
  /// `.eq('matter_id', matterId)` server-side.
  Future<List<Map<String, dynamic>>> fetchFiles({String? matterId});

  /// Resolves the matter under the caller's RLS gate for an upload.
  ///
  /// Returns an empty map when no row is readable (the gateway maps that to
  /// a denial).
  Future<Map<String, dynamic>> fetchMatterForUpload(String matterId);

  /// Uploads [bytes] to `matter-files` at [path].
  Future<void> uploadObject(String path, Uint8List bytes, String contentType);

  /// Creates a signed URL for [path].
  Future<String> createSignedUrl(String path, int expiresInSeconds);

  /// Best-effort object cleanup after a failed metadata registration.
  Future<void> removeObject(String path);

  /// Calls `register_matter_file` and returns `{file, matter_title}`.
  Future<Map<String, dynamic>> registerMatterFile({
    required String matterId,
    required String name,
    required String mimeType,
    required int sizeBytes,
    required String storagePath,
  });
}
