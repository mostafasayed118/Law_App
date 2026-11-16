/// Provider-neutral Legal Library RPC seam (ADR-0009).
///
/// The seam is the only surface the library gateway talks to: plain map rows
/// out, a typed [SupabaseLibraryException] on failure. Provider types never
/// cross this boundary (same discipline as `SupabaseAttorneyApi`).
///
/// Four reads, no writes. The library is populated by the owner's importer, so
/// there is no create/update/delete here at all.
library;

/// Typed reasons a library read can fail, mapped from PostgREST.
enum SupabaseLibraryFailureKind {
  /// The caller is not permitted (no session, no EXECUTE grant).
  denied,

  /// The RPC returned no row for the requested id.
  notFound,

  /// The server refused the input (query over the length cap).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseLibraryApi] seam.
class SupabaseLibraryException implements Exception {
  const SupabaseLibraryException({required this.kind, required this.message});

  final SupabaseLibraryFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseLibraryException(${kind.name}): $message';
}

/// The Legal Library surface backed by the Supabase PostgREST client.
///
/// `category` travels as the raw schema enum value (`civil`, `labor`, …), not as
/// a Dart enum name, so the seam stays wire-typed and the gateway owns the
/// translation in one place.
abstract interface class SupabaseLibraryApi {
  /// Documents, newest publication first. [limit] is clamped server-side to 50.
  Future<List<Map<String, dynamic>>> listDocuments({
    String? category,
    int limit = 50,
    int offset = 0,
  });

  /// One document with up to [articleLimit] articles in reading order.
  ///
  /// Returns an empty list when the id does not exist; the gateway maps that to
  /// a typed not-found rather than a silently empty document.
  Future<List<Map<String, dynamic>>> getDocument(
    String id, {
    int articleLimit = 200,
  });

  /// One article with its document context and neighbours. Empty when missing.
  Future<List<Map<String, dynamic>>> getArticle(String id);

  /// Ranked article hits. An empty query returns no rows (never an error).
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String? category,
    int limit = 20,
    int offset = 0,
  });
}
