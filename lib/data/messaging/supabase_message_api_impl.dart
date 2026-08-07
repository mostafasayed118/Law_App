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
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
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
