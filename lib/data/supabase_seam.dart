import 'package:supabase_flutter/supabase_flutter.dart';

import 'list_query_guards.dart';

/// The single home for Supabase provider bindings (audit: seam duplication).
///
/// Nine `*_api_impl.dart` files each carried byte-identical `_boundRpc` /
/// `_boundTable` statics (plus the postgrest 2.8.0 wrap explanation
/// copy-pasted in three of them): a provider-contract change needed nine
/// coordinated edits and a miss would have silently split the seam. The
/// impls now delegate here — one place to fix the RPC-await contract, the
/// row-cap policy, and the paging helpers.
///
/// Test seam discipline is unchanged: each impl still injects a plain
/// function type (`OrgRpcCaller`, `MatterTableCaller`, …) and exposes a
/// `.bind()` factory — the factory now points at these shared bindings
/// instead of a file-local copy. Private `_boundX` statics stay on the
/// impls as one-line delegates so existing `.bind()` tear-offs keep their
/// shape.
class SupabaseSeam {
  SupabaseSeam._();

  /// Wraps raw RPC data into the seam's `PostgrestResponse` shape.
  ///
  /// postgrest 2.8.0 contract: `await rpc<T>()` resolves to the RAW decoded
  /// data (T), NOT a `PostgrestResponse` — the wrapper is only produced when
  /// a count is requested. The seam's callers (and the test stubs) expect
  /// the wrapped shape, so the production binding wraps here;
  /// `PostgrestException` still propagates from the await unchanged.
  static PostgrestResponse<dynamic> wrapRpcData(dynamic data) {
    return PostgrestResponse<dynamic>(data: data, count: 0);
  }

  /// Shared RPC binding: function + named params → wrapped response.
  static Future<PostgrestResponse<dynamic>> boundRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final dynamic data = await Supabase.instance.client
        .rpc<dynamic>(function, params: params)
        .timeout(const Duration(seconds: 15));
    return wrapRpcData(data);
  }

  /// Shared raw RPC binding for seams whose callers consume the decoded
  /// payload directly (notifications D-N6 write RPC).
  static Future<Object?> boundRawRpc(
    String function,
    Map<String, dynamic>? params,
  ) {
    return Supabase.instance.client
        .rpc<Object?>(function, params: params)
        .timeout(const Duration(seconds: 15));
  }

  /// Shared table-SELECT binding: the bounded, deterministically ordered
  /// read from [boundedTableSelect] (hard row cap + index-backed order).
  static Future<List<Map<String, dynamic>>> boundTable(
    String table,
    String columns,
  ) {
    return boundedTableSelect(table, columns);
  }

  /// Shared filtered table-SELECT binding (e.g. `thread_id` scoping on the
  /// messaging read): equality filter + cap + deterministic order.
  static Future<List<Map<String, dynamic>>> boundFilteredTable(
    String table,
    String columns, {
    String? filterColumn,
    Object? filterValue,
  }) {
    return boundedTableSelect(
      table,
      columns,
      filterColumn: filterColumn,
      filterValue: filterValue,
    );
  }

  /// Shared server-side search binding: first page of a case-insensitive
  /// substring (`ilike`) match over [ilikeColumn], newest-first per the
  /// table's deterministic ordering.
  ///
  /// Audit (search fan-out): the unified search fan-out fetched four full
  /// capped lists (up to 800 rows) per query and filtered client-side. This
  /// binding pushes a recall-oriented title prefilter to the server
  /// (4 × [limit] rows) — callers MUST still apply their full matching
  /// pass client-side (localized labels, enum names, and participant names
  /// never cross the seam), so results keep their exact matching semantics
  /// and only the transfer volume shrinks. The column passes through the
  /// [requireFilterableColumn] allowlist inside [pagedTableSelect].
  static Future<List<Map<String, dynamic>>> boundSearchTable(
    String table,
    String columns,
    String ilikeColumn,
    String needle, {
    int limit = kSearchPageSize,
  }) {
    return pagedTableSelect(
      table,
      columns,
      pageSize: limit,
      ilikeColumn: ilikeColumn,
      ilikeValue: needle,
    );
  }
}
