import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_message_api.dart';

/// [SupabaseMessageApi] backed by the PostgREST client.
///
/// Like [SupabaseDocumentApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseMessageException]s at the seam.
class SupabaseMessageApiImpl implements SupabaseMessageApi {
  SupabaseMessageApiImpl(
    this._table, {
    MessageOrgCaller? orgCaller,
    MessageInsertCaller? insertCaller,
  }) : _orgCaller = orgCaller ?? _boundOrg,
       _insertCaller = insertCaller ?? _boundInsert;

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
  final MessageOrgCaller _orgCaller;
  final MessageInsertCaller _insertCaller;

  /// Binds a single-row SELECT by id (the send path's thread-org
  /// resolution, D-LV1). `maybeSingle` returns null when the row is not
  /// visible under the caller's RLS — an unassigned writer cannot read the
  /// thread's org and therefore cannot send.
  static Future<Map<String, dynamic>?> _boundOrg(
    String table,
    String id,
  ) async {
    return Supabase.instance.client
        .from(table)
        .select('organization_id')
        .eq('id', id)
        .maybeSingle();
  }

  /// Binds a PostgREST INSERT returning the persisted row (D-LV1). The
  /// single row comes back via `.select().single()`, so the gateway can map
  /// the created message without a follow-up read.
  static Future<Map<String, dynamic>> _boundInsert(
    String table,
    Map<String, dynamic> row,
  ) async {
    return Supabase.instance.client.from(table).insert(row).select().single();
  }

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
  Future<Map<String, dynamic>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    try {
      // The messages_insert_assigned WITH CHECK needs the row's
      // organization_id (NOT NULL, no default). Resolve the thread's org
      // under the SAME RLS gate first: the caller must be assigned on the
      // thread's matter to read it, and the org it returns IS the org the
      // policy will re-check. An unreadable org = the write cannot be
      // authorized — a typed denial, never a silent insert attempt.
      final Map<String, dynamic>? orgRow = await _orgCaller(
        'message_threads',
        threadId,
      );
      final Object? org = orgRow?['organization_id'];
      if (org is! String || org.isEmpty) {
        throw const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.denied,
          message: 'Thread organization is not readable.',
        );
      }
      return await _insertCaller('messages', <String, dynamic>{
        'organization_id': org,
        'thread_id': threadId,
        // D-RT4 stored-name convention: the caller's session display name
        // when provided; a neutral generic demo name otherwise (never a
        // fabricated real identity).
        'author_display_name':
            (authorDisplayName == null || authorDisplayName.trim().isEmpty)
            ? 'Demo client'
            : authorDisplayName.trim(),
        'body': body,
      });
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
