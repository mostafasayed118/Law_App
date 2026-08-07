/// Provider-neutral message-thread table seam.
///
/// The seam is the only surface the message gateway talks to: plain map rows
/// out, typed [SupabaseMessageException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseDocumentApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// The callable the impl injects (mirrors `DocumentTableCaller` from the
/// documents seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types.
typedef MessageTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// Typed reasons the message-thread read can fail, mapped from the PostgREST
/// surface. The read path is a plain RLS-scoped SELECT — the RPC-specific
/// kinds of the organization seam cannot occur here.
enum SupabaseMessageFailureKind {
  /// The caller is not permitted to read the requested rows (RLS denied or
  /// the caller has no session).
  denied,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseMessageApi] seam.
class SupabaseMessageException implements Exception {
  const SupabaseMessageException({required this.kind, required this.message});

  final SupabaseMessageFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseMessageException(${kind.name}): $message';
}

/// Message-threads table surface backed by the Supabase PostgREST client.
///
/// The SELECT is RLS-scoped (plan D-MSR1/D-MSR2): the
/// `message_threads_select_assigned` policy returns only the rows whose
/// matter the caller is assigned to (client or attorney) as an active member
/// of the thread's org. Rows carry ids + the embedded matter title — the
/// gateway resolves the VO's title-keyed `matterRef` from the embed, falling
/// back to the raw matter id (D-MSR4).
abstract interface class SupabaseMessageApi {
  /// The caller's assignment-scoped `message_threads` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `title`, `participants`,
  /// `message_count`, `last_activity_at`, `matters(title)` — the
  /// metadata-only read surface the [MessageThread] VO needs (D-MSG1: no
  /// body/preview/attachment/sender column exists).
  Future<List<Map<String, dynamic>>> fetchMessageThreads();
}
