/// Provider-neutral files-table seam.
///
/// The seam is the only surface the storage gateway talks to: plain map rows
/// out, typed [SupabaseStorageException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseDocumentApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `DocumentTableCaller` from the
/// documents seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef StorageTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// Typed reasons the files read can fail, mapped from the PostgREST surface.
/// The read path is a plain RLS-scoped SELECT — the RPC-specific kinds of
/// the organization seam cannot occur here.
enum SupabaseStorageFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
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

/// Files-table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (plan D-STR1/D-STR2): the `files_select_assigned`
/// policy returns only the rows whose matter the caller is assigned to
/// (client or attorney) as an active member of the file's org. Rows carry ids
/// + the embedded matter title — the gateway resolves the VO's title-keyed
/// `matterRef` from the embed, falling back to the raw matter id (D-STR5).
/// The byte-level read (`storage.from('matter-files').download(...)`) is a
/// flagged follow-up slice (D-STR9); the storage.objects policy + battery
/// prove the byte gate server-side.
abstract interface class SupabaseStorageApi {
  /// The caller's assignment-scoped `files` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `name`, `mime_type`,
  /// `size_bytes`, `storage_path`, `matters(title)` — the metadata-only read
  /// surface the [FileMetadata] VO needs (D-STR3: no content/body/url column
  /// exists).
  Future<List<Map<String, dynamic>>> fetchFiles();
}
