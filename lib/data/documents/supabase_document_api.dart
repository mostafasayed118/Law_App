/// Provider-neutral document table seam.
///
/// The seam is the only surface the document gateway talks to: plain map rows
/// out, typed [SupabaseDocumentException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseMatterApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `MatterTableCaller` from the
/// matters seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef DocumentTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// Typed reasons the documents read can fail, mapped from the PostgREST
/// surface. The read path is a plain RLS-scoped SELECT — the RPC-specific
/// kinds of the organization seam cannot occur here.
enum SupabaseDocumentFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseDocumentApi] seam.
class SupabaseDocumentException implements Exception {
  const SupabaseDocumentException({required this.kind, required this.message});

  final SupabaseDocumentFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseDocumentException(${kind.name}): $message';
}

/// Documents table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (plan D-DR1/D-DR2): the
/// `documents_select_assigned` policy returns only the rows whose matter the
/// caller is assigned to (client or attorney) as an active member of the
/// document's org. Rows carry ids + the embedded matter title — the gateway
/// resolves the VO's title-keyed `matterRef` from the embed, falling back to
/// the raw matter id (D-DR4).
abstract interface class SupabaseDocumentApi {
  /// The caller's assignment-scoped `documents` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `title`, `document_type`,
  /// `created_at`, `matters(title)` — the metadata-only read surface the
  /// [Document] VO needs (D-V1: no body/content/size/url column exists).
  Future<List<Map<String, dynamic>>> fetchDocuments();
}
