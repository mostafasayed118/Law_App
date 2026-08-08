/// Provider-neutral message-thread table seam.
///
/// The seam is the only surface the message gateway talks to: plain map rows
/// out, typed [SupabaseMessageException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseDocumentApi]).
library;

/// A PostgREST table SELECT: table name + columns → raw map rows, with an
/// optional `thread_id` filter.
///
/// The callable the impl injects (mirrors `DocumentTableCaller` from the
/// documents seam). Plain function type so tests inject a closure and the
/// provider binding is the only file that touches provider types. The
/// optional `threadId` filters the SELECT with `.eq('thread_id', …)` — the
/// thread-scoped messages read (D-RT5); the threads read passes null.
typedef MessageTableCaller =
    Future<List<Map<String, dynamic>>> Function(
      String table,
      String columns, [
      String? threadId,
    ]);

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

/// Message-threads + messages table surface backed by the Supabase
/// PostgREST client.
///
/// The thread SELECT is RLS-scoped (plan D-MSR1/D-MSR2): the
/// `message_threads_select_assigned` policy returns only the rows whose
/// matter the caller is assigned to (client or attorney) as an active member
/// of the thread's org. Rows carry ids + the embedded matter title — the
/// gateway resolves the VO's title-keyed `matterRef` from the embed, falling
/// back to the raw matter id (D-MSR4).
///
/// The message SELECT is the thread gate extended one hop (D-RT2):
/// `messages_select_assigned` returns only the rows whose thread's matter
/// the caller is assigned to — and the three-way org equality is
/// load-bearing, so a message is never readable when its thread or matter is
/// not. The `body` column is the D-MSG1 consummation (first content column
/// in the public schema) — read path only.
abstract interface class SupabaseMessageApi {
  /// The caller's assignment-scoped `message_threads` rows.
  ///
  /// Columns requested: `id`, `matter_id`, `title`, `participants`,
  /// `message_count`, `last_activity_at`, `matters(title)` — the
  /// metadata-only read surface the [MessageThread] VO needs (D-MSG1: no
  /// body/preview/attachment/sender column exists).
  Future<List<Map<String, dynamic>>> fetchMessageThreads();

  /// The caller's assignment-scoped `messages` rows for one thread.
  ///
  /// Columns requested: `id`, `thread_id`, `author_display_name`, `body`,
  /// `sent_at` — the read-path surface the [Message] VO needs (D-RT3/D-RT5:
  /// no attachment/read-receipt/user-id column is ever read). The SELECT is
  /// filtered `.eq('thread_id', threadId)` so only the tapped thread's rows
  /// cross the seam.
  Future<List<Map<String, dynamic>>> fetchMessages(String threadId);

  /// Sends one message on the thread through the audited `send_message`
  /// RPC (D-SM2) and returns the persisted message id.
  ///
  /// The RPC is the ONLY message write path (D-SM3 — the direct-INSERT
  /// grant is revoked and `messages_insert_assigned` dropped), so the
  /// write is contract §8-audited by construction. The thread's org
  /// resolution moved INTO the function (gate review Q4), so the client
  /// sends only the thread id + body — no org pre-read — and the author
  /// is derived in-function from profiles (the D-RT4 stored-name
  /// convention), so no author is sent either. The RPC returns the
  /// persisted message id (uuid); the gateway resolves the full row
  /// through the shipped fetch read.
  Future<String> sendMessage(String threadId, String body);
}
