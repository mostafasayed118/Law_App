import 'package:legalhub/core/pagination.dart';
import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_matter_api.dart';

/// [SupabaseMatterApi] backed by the PostgREST client.
///
/// Like [SupabaseOrgApiImpl], this is a data-layer file whose only job is
/// holding the provider import: a table SELECT in, plain map rows out, and
/// PostgrestExceptions mapped to [SupabaseMatterException]s at the seam.
class SupabaseMatterApiImpl implements SupabaseMatterApi {
  SupabaseMatterApiImpl(this._table, {MatterSearchCaller? searchCaller})
    : _searchCaller = searchCaller ?? _boundSearch;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseMatterApiImpl.bind() => SupabaseMatterApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first `.order('created_at')`
  /// + a hard row cap, so a single read can never pull an entire
  /// RLS-visible table (audit 2026-09-21, P1).
  /// Shared seam binding ([SupabaseSeam.boundTable]).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// Binds the search read to the app-level client via the shared bounded
  /// table binding: the RLS-scoped page (cap 200), newest-first. The
  /// title-only SQL prefilter was deliberately dropped — the client matcher
  /// also matches status, practice area, and localized labels the server
  /// cannot express, and a title prefilter silently discarded those hits.
  /// The bounded page is the superset; the caller refines it and takes the
  /// requested top-N.
  static Future<List<Map<String, dynamic>>> _boundSearch(
    String table,
    String columns,
    String ilikeColumn,
    String needle,
    int limit,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  final MatterTableCaller _table;
  final MatterSearchCaller _searchCaller;

  @override
  Future<List<Map<String, dynamic>>> fetchMatters() async {
    try {
      // RLS-scoped (D-MR1): `matters_select_assigned` returns only the
      // caller's assigned rows; ids only, names resolve via the roster seam
      // (D-MR4). `assigned_attorney_id` may be null (no attorney assigned).
      return await _table(
        SupabaseTables.matters,
        'id, organization_id, title, practice_area, status, '
        'assigned_attorney_id, created_at',
      );
    } on PostgrestException catch (e) {
      throw SupabaseMatterException(kind: _kindFor(e), message: e.message);
    } on Exception {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth impl's
      // defensive-catch precedent).
      throw const SupabaseMatterException(
        kind: SupabaseMatterFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1): this impl supplies only its enum values, the match-once logic
  /// lives in `postgrest_failures.dart`.
  SupabaseMatterFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseMatterFailureKind.denied,
      unknown: SupabaseMatterFailureKind.unknown,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> searchMatters(
    String query, {
    int limit = kSearchPageSize,
  }) async {
    try {
      // Same RLS scope and columns as fetchMatters (D-MR1/D-MR4). The read
      // is the bounded page (cap 200); the caller applies its full matching
      // pass and takes the requested top-N (see _boundSearch for why the
      // title-only SQL prefilter was dropped).
      return await _searchCaller(
        SupabaseTables.matters,
        'id, organization_id, title, practice_area, status, '
            'assigned_attorney_id, created_at',
        'title',
        query,
        limit,
      );
    } on PostgrestException catch (e) {
      throw SupabaseMatterException(kind: _kindFor(e), message: e.message);
    } on Exception {
      throw const SupabaseMatterException(
        kind: SupabaseMatterFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }
}
