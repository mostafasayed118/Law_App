import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_document_api.dart';

/// [SupabaseDocumentApi] backed by the PostgREST client.
///
/// Like [SupabaseMatterApiImpl], this is a data-layer file whose only job is
/// holding the provider import: a table SELECT in, plain map rows out, and
/// PostgrestExceptions mapped to [SupabaseDocumentException]s at the seam.
class SupabaseDocumentApiImpl implements SupabaseDocumentApi {
  SupabaseDocumentApiImpl(
    this._table, {
    DocumentSearchCaller? searchCaller,
    DocumentMatterTableCaller? matterTableCaller,
  }) : _searchCaller = searchCaller ?? _boundSearch,
       _matterTable = matterTableCaller ?? _boundMatterTable;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseDocumentApiImpl.bind() =>
      SupabaseDocumentApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('created_at')`
  /// + a hard row cap (audit 2026-09-21, P1).
  /// Shared seam binding ([SupabaseSeam.boundTable]).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// Binds the search read to the app-level client via the shared bounded
  /// table binding: the RLS-scoped page (cap 200), newest-first, with the
  /// same `matters(title)` embed as the fetch read. The title-only SQL
  /// prefilter was deliberately dropped — the client matcher also matches
  /// document type and the embedded matter title, which the server cannot
  /// express in a single column filter. The bounded page is the superset;
  /// the caller refines it and takes the requested top-N.
  static Future<List<Map<String, dynamic>>> _boundSearch(
    String table,
    String columns,
    String ilikeColumn,
    String needle,
    int limit,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// Binds the matter-scoped read to the app-level client via the shared
  /// filtered binding: the same cap + order as [boundTable], with
  /// `.eq('matter_id', …)` applied server-side.
  static Future<List<Map<String, dynamic>>> _boundMatterTable(
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

  final DocumentTableCaller _table;
  final DocumentSearchCaller _searchCaller;
  final DocumentMatterTableCaller _matterTable;

  @override
  Future<List<Map<String, dynamic>>> fetchDocuments({String? matterId}) async {
    try {
      // RLS-scoped (D-DR1/D-DR2): `documents_select_assigned` returns only
      // the caller's rows; the matterRef title comes from the embedded
      // matters(title) select (D-DR4), never a blocked `profiles` join.
      // A non-null [matterId] narrows the transfer to the open matter.
      const String columns =
          'id, matter_id, title, document_type, created_at, matters(title)';
      return matterId == null
          ? await _table('documents', columns)
          : await _matterTable('documents', columns, matterId);
    } on PostgrestException catch (e) {
      throw SupabaseDocumentException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseDocumentException(
        kind: SupabaseDocumentFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1): this impl supplies only its enum values, the match-once logic
  /// lives in `postgrest_failures.dart`.
  SupabaseDocumentFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseDocumentFailureKind.denied,
      unknown: SupabaseDocumentFailureKind.unknown,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchDocuments(
    String query, {
    int limit = 30,
  }) async {
    try {
      // Same RLS scope, columns, and matters(title) embed as fetchDocuments
      // (D-DR1/D-DR2/D-DR4). The read is the bounded page (cap 200); the
      // caller applies its full matching pass and takes the requested
      // top-N (see _boundSearch for why the title-only SQL prefilter was
      // dropped).
      return await _searchCaller(
        'documents',
        'id, matter_id, title, document_type, created_at, matters(title)',
        'title',
        query,
        limit,
      );
    } on PostgrestException catch (e) {
      throw SupabaseDocumentException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabaseDocumentException(
        kind: SupabaseDocumentFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }
}
