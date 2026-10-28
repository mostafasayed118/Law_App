/// Provider-neutral matter table seam.
///
/// The seam is the only surface the matter gateway talks to: plain map rows
/// out, typed [SupabaseMatterException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseOrgApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `OrgTableCaller` from the
/// organization seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef MatterTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// A server-side title search: table + columns + ilike column + needle +
/// page size → raw map rows.
///
/// Separate callable (rather than widening [MatterTableCaller]) so existing
/// test injections of the two-arg fetch shape keep compiling; the search
/// binding is the only file that touches the ilike path.
typedef MatterSearchCaller =
    Future<List<Map<String, dynamic>>> Function(
      String table,
      String columns,
      String ilikeColumn,
      String needle,
      int limit,
    );

/// Typed reasons the matters read can fail, mapped from the PostgREST
/// surface. The read path is a plain RLS-scoped SELECT — the RPC-specific
/// kinds of the organization seam cannot occur here.
enum SupabaseMatterFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseMatterApi] seam.
class SupabaseMatterException implements Exception {
  const SupabaseMatterException({required this.kind, required this.message});

  final SupabaseMatterFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseMatterException(${kind.name}): $message';
}

/// Matters table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (plan D-MR1): the `matters_select_assigned`
/// policy returns only the rows the caller is assigned to (client or
/// attorney) as an active member of the matter's org. Rows carry ids —
/// display names are resolved by the gateway through the shipped roster
/// seam (D-MR4), never through a blocked `profiles` join.
abstract interface class SupabaseMatterApi {
  /// The caller's assignment-scoped `matters` rows.
  ///
  /// Columns requested: `id`, `organization_id`, `title`, `practice_area`,
  /// `status`, `assigned_attorney_id`, `created_at` — the full read surface
  /// the [Matter] VO needs (names resolve via the roster, D-MR4).
  Future<List<Map<String, dynamic>>> fetchMatters();

  /// First page of the caller's assignment-scoped `matters` rows whose
  /// `title` matches [query] (case-insensitive substring, newest-first).
  ///
  /// Same columns and RLS scope as [fetchMatters]; the recall-oriented
  /// prefilter for unified search (audit: search fan-out). The caller
  /// still applies its full matching pass — a title prefilter only.
  Future<List<Map<String, dynamic>>> searchMatters(String query, {int limit});
}
