import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_message_api.dart';

/// [SupabaseMessageApi] backed by the PostgREST client.
///
/// Like [SupabaseDocumentApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseMessageException]s at the seam.
class SupabaseMessageApiImpl implements SupabaseMessageApi {
  SupabaseMessageApiImpl(this._table);

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseMessageApiImpl.bind() => SupabaseMessageApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed. When a
  /// `threadId` is given, the SELECT is filtered `.eq('thread_id', …)` — the
  /// thread-scoped messages read (D-RT5).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns, [
    String? threadId,
  ]) {
    final PostgrestFilterBuilder<List<Map<String, dynamic>>> query = Supabase
        .instance
        .client
        .from(table)
        .select(columns);
    return threadId == null ? query : query.eq('thread_id', threadId);
  }

  final MessageTableCaller _table;

  @override
  Future<List<Map<String, dynamic>>> fetchMessageThreads() async {
    try {
      // RLS-scoped (D-MSR1/D-MSR2): `message_threads_select_assigned`
      // returns only the caller's rows; the matterRef title comes from the
      // embedded matters(title) select (D-MSR4), never a blocked `profiles`
      // join.
      return await _table(
        'message_threads',
        'id, matter_id, title, participants, message_count, '
            'last_activity_at, matters(title)',
      );
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async {
    try {
      // RLS-scoped (D-RT2): `messages_select_assigned` returns only the
      // rows whose thread's matter the caller is assigned to; the SELECT is
      // filtered `.eq('thread_id', …)` so only the tapped thread's rows
      // cross the seam. The body column is the D-MSG1 consummation — read
      // path only (D-RT5).
      return await _table(
        'messages',
        'id, thread_id, author_display_name, body, sent_at',
        threadId,
      );
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Object {
      // Same defensive catch as fetchMessageThreads: a non-Postgrest
      // provider failure is a typed unavailable, never a raw exception
      // across the seam (the auth impl's defensive-catch precedent).
      throw const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseMessageFailureKind.unknown] with the message preserved.
  SupabaseMessageFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseMessageFailureKind.denied;
    }
    return SupabaseMessageFailureKind.unknown;
  }
}
