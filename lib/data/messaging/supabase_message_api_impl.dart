import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_message_api.dart';

/// A PostgREST RPC call: function name + named params → response.
///
/// The callable the impl injects for the audited send path (D-SM2) —
/// mirrors `OrgRpcCaller`/`PlatformAdminRpcCaller` from the org/admin
/// seams. Plain function type so tests inject a closure and the impl is the
/// only file that ever touches provider types.
typedef MessageRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseMessageApi] backed by the PostgREST client.
///
/// Like [SupabaseDocumentApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseMessageException]s at the seam.
class SupabaseMessageApiImpl implements SupabaseMessageApi {
  SupabaseMessageApiImpl(this._table, {MessageRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

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

  /// Binds the audited `send_message` RPC to the app-level client (D-SM2).
  /// `rpc<T>` builders implement `Future<dynamic>` (T = the data type), so
  /// the awaited value is the full PostgrestResponse at runtime — cast,
  /// not wrap, so errors and status flow through unchanged.
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final dynamic response = await Supabase.instance.client.rpc<dynamic>(
      function,
      params: params,
    );
    return response as PostgrestResponse<dynamic>;
  }

  final MessageTableCaller _table;
  final MessageRpcCaller _rpcCaller;

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

  @override
  Future<String> sendMessage(String threadId, String body) async {
    try {
      // D-SM2: the audited `send_message` RPC is the ONLY message write
      // path (D-SM3 — the direct INSERT grant is revoked and
      // `messages_insert_assigned` dropped). The thread's org resolution
      // moved INTO the function (gate review Q4) and the author is derived
      // in-function from profiles (D-RT4 stored-name convention), so the
      // client sends only the thread id + body — no org pre-read, no
      // author. The function returns the persisted message id (uuid).
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'send_message',
        <String, dynamic>{'p_thread_id': threadId, 'p_body': body},
      );
      final Object? id = response.data;
      if (id is! String || id.isEmpty) {
        throw const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.unknown,
          message: 'send_message returned no id.',
        );
      }
      return id;
    } on SupabaseMessageException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Object {
      // Same defensive catch as the reads: a non-Postgrest provider failure
      // is a typed unavailable, never a raw exception across the seam.
      throw const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable denial text (including the RPC's in-function `raise
  /// exception 'permission denied'`) is the only fragment matched;
  /// everything else is [SupabaseMessageFailureKind.unknown] with the
  /// message preserved.
  SupabaseMessageFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseMessageFailureKind.denied;
    }
    return SupabaseMessageFailureKind.unknown;
  }
}
