import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
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
  SupabaseMessageApiImpl(
    this._table, {
    MessageRpcCaller? rpcCaller,
    MessageSearchCaller? searchCaller,
    MessageMatterTableCaller? matterTableCaller,
  }) : _rpcCaller = rpcCaller ?? _boundRpc,
       _searchCaller = searchCaller ?? _boundSearch,
       _matterTable = matterTableCaller ?? _boundMatterThreads;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseMessageApiImpl.bind() => SupabaseMessageApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): threads ordered newest-activity
  /// first, messages fetched NEWEST-first (the cap must keep the newest
  /// end of the history; the gateway reverses to chronological for the
  /// detail screen's top-to-bottom render), each with a hard row cap
  /// (audit 2026-09-21, P1). When a `threadId` is given, the SELECT is
  /// filtered `.eq('thread_id', …)` — the thread-scoped messages read
  /// (D-RT5).
  /// Shared seam bindings ([SupabaseSeam.boundFilteredTable] for the
  /// `thread_id`-scoped read, [SupabaseSeam.boundRpc] for `send_message`).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns, [
    String? threadId,
  ]) {
    return SupabaseSeam.boundFilteredTable(
      table,
      columns,
      filterColumn: threadId == null ? null : 'thread_id',
      filterValue: threadId,
    );
  }

  /// Binds the matter-scoped thread read to the app-level client via the
  /// shared filtered binding: the same cap + order as [boundTable], with
  /// `.eq('matter_id', …)` applied server-side.
  static Future<List<Map<String, dynamic>>> _boundMatterThreads(
    String table,
    String columns,
    String matterId,
  ) {
    return SupabaseSeam.boundFilteredTable(
      table,
      columns,
      filterColumn: 'matter_id',
      filterValue: matterId,
    );
  }

  /// Binds the audited `send_message` RPC to the app-level client (D-SM2).
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  /// Binds the thread-search read to the app-level client via the shared
  /// bounded table binding: the RLS-scoped page (cap 200),
  /// newest-activity-first, with the same `matters(title)` embed as the
  /// threads read. The title-only SQL prefilter was deliberately dropped —
  /// the client matcher also matches matter references and participants,
  /// which the server cannot express in a single column filter. The bounded
  /// page is the superset; the caller refines it and takes the top-N.
  static Future<List<Map<String, dynamic>>> _boundSearch(
    String table,
    String columns,
    String ilikeColumn,
    String needle,
    int limit,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  final MessageTableCaller _table;
  final MessageRpcCaller _rpcCaller;
  final MessageSearchCaller _searchCaller;
  final MessageMatterTableCaller _matterTable;

  @override
  Future<List<Map<String, dynamic>>> fetchMessageThreads({
    String? matterId,
  }) async {
    try {
      // RLS-scoped (D-MSR1/D-MSR2): `message_threads_select_assigned`
      // returns only the caller's rows; the matterRef title comes from the
      // embedded matters(title) select (D-MSR4), never a blocked `profiles`
      // join. A non-null [matterId] narrows the transfer to the open matter.
      const String columns =
          'id, matter_id, title, participants, message_count, '
          'last_activity_at, matters(title)';
      return matterId == null
          ? await _table('message_threads', columns)
          : await _matterTable('message_threads', columns, matterId);
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Exception {
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
  Future<List<Map<String, dynamic>>> searchMessageThreads(
    String query, {
    int limit = 30,
  }) async {
    try {
      // Same RLS scope, columns, and matters(title) embed as
      // fetchMessageThreads (D-MSR1/D-MSR2/D-MSR4). The read is the bounded
      // page (cap 200); the caller applies its full matching pass
      // (participants included) and takes the requested top-N (see
      // _boundSearch for why the title-only SQL prefilter was dropped).
      return await _searchCaller(
        'message_threads',
        'id, matter_id, title, participants, message_count, '
            'last_activity_at, matters(title)',
        'title',
        query,
        limit,
      );
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Exception {
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
    } on Exception {
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
  Future<Map<String, dynamic>> sendMessage(String threadId, String body) async {
    try {
      // D-SM2: the audited `send_message` RPC is the ONLY message write
      // path (D-SM3 — the direct INSERT grant is revoked and
      // `messages_insert_assigned` dropped). The thread's org resolution
      // moved INTO the function (gate review Q4) and the author is derived
      // in-function from profiles (D-RT4 stored-name convention), so the
      // client sends only the thread id + body — no org pre-read, no
      // author. The function returns the persisted row as jsonb (audit
      // follow-up 2026-09-27): the gateway maps the VO from this response
      // directly — no follow-up fetchMessages re-read per send.
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'send_message',
        <String, dynamic>{'p_thread_id': threadId, 'p_body': body},
      );
      final Object? data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.unknown,
          message: 'send_message returned no row.',
        );
      }
      return data;
    } on SupabaseMessageException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseMessageException(kind: _kindFor(e), message: e.message);
    } on Exception {
      // Same defensive catch as the reads: a non-Postgrest provider failure
      // is a typed unavailable, never a raw exception across the seam.
      throw const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1). Covers the reads AND the RPC's in-function `raise exception
  /// 'permission denied'` (same stable text); this impl supplies only its
  /// enum values, the match-once logic lives in `postgrest_failures.dart`.
  SupabaseMessageFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseMessageFailureKind.denied,
      unknown: SupabaseMessageFailureKind.unknown,
    );
  }
}
