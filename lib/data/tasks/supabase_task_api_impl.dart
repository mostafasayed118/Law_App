import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_task_api.dart';

/// A PostgREST RPC call: function name + named params → response.
///
/// The callable the impl injects for the four audited task RPCs (Gate 3
/// spec 2026-09-27) — mirrors `MessageRpcCaller` from the messaging seam.
/// Plain function type so tests inject a closure and the impl is the only
/// file that ever touches provider types.
typedef TaskRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseTaskApi] backed by the PostgREST client.
///
/// Like [SupabaseMessageApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// RPC responses as single map rows, and PostgrestExceptions mapped to
/// [SupabaseTaskException]s at the seam.
class SupabaseTaskApiImpl implements SupabaseTaskApi {
  SupabaseTaskApiImpl(this._table, {TaskRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseTaskApiImpl.bind() => SupabaseTaskApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first with a hard row cap
  /// (audit 2026-09-21, P1). Shared seam binding
  /// ([SupabaseSeam.boundFilteredTable] with no filter — the
  /// `tasks_select_assigned` RLS policy is the scope).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns, [
    String? _,
  ]) {
    return SupabaseSeam.boundFilteredTable(table, columns);
  }

  /// Binds the four audited task RPCs to the app-level client (Gate 3).
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  /// The task-row columns every read and every RPC response carries: ids,
  /// title, server status, assignee + acknowledgement stamps, and the
  /// embedded matter title for the VO's title-keyed `matterRef` (D-MSR4).
  static const String _taskColumns =
      'id, organization_id, matter_id, title, status, assignee_id, '
      'acknowledged_by, acknowledged_at, created_at, matters(title)';

  final Future<List<Map<String, dynamic>>> Function(
    String table,
    String columns, [
    String? threadId,
  ])
  _table;
  final TaskRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> fetchTasks() async {
    try {
      // RLS-scoped: `tasks_select_assigned` returns only the rows whose
      // matter the caller is assigned to as an active member of the task's
      // org (the org-mismatch equality is load-bearing).
      return await _table('tasks', _taskColumns);
    } on PostgrestException catch (e) {
      throw SupabaseTaskException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    // `create_task` is the ONLY task-create path (no INSERT policy or grant
    // on `tasks`). The matter's org resolution + the assignment gate run
    // in-function, so the client sends only the matter id + title (+ an
    // optional assignee id) — no org pre-read. Returns the persisted row.
    return _callRpc('create_task', <String, dynamic>{
      'p_matter_id': matterId,
      'p_assignee_id': assigneeId,
      'p_title': title,
    });
  }

  @override
  Future<Map<String, dynamic>> advanceTaskStatus(
    String taskId,
    String toStatus,
  ) {
    return _callRpc('advance_task_status', <String, dynamic>{
      'p_task_id': taskId,
      'p_to_status': toStatus,
    });
  }

  @override
  Future<Map<String, dynamic>> assignTask(String taskId, String? assigneeId) {
    return _callRpc('assign_task', <String, dynamic>{
      'p_task_id': taskId,
      'p_assignee_id': assigneeId,
    });
  }

  @override
  Future<Map<String, dynamic>> acknowledgeTask(String taskId) {
    return _callRpc('acknowledge_task', <String, dynamic>{'p_task_id': taskId});
  }

  /// Calls one audited task RPC and returns its persisted-row response.
  ///
  /// A non-row response is a typed unknown (provider drift), never a cast
  /// error across the seam; Postgrest failures classify through [_kindFor].
  Future<Map<String, dynamic>> _callRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        function,
        params,
      );
      final Object? data = response.data;
      if (data is! Map<String, dynamic>) {
        throw SupabaseTaskException(
          kind: SupabaseTaskFailureKind.unknown,
          message: '$function returned no row.',
        );
      }
      return data;
    } on SupabaseTaskException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseTaskException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabaseTaskException(
        kind: SupabaseTaskFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind: the
  /// shared denial rule ([isPostgrestDenial] — covers the RPCs' in-function
  /// `raise exception 'permission denied'` with its stable text) plus the
  /// validation arm for the RPCs' validation gates. The gates raise
  /// `using errcode = 'check_violation'` (the Batch B convention), which
  /// PostgREST surfaces as the SQLSTATE digits `23514` in `code` — the arm
  /// matches the digits, never the condition name. Everything else is
  /// unknown.
  SupabaseTaskFailureKind _kindFor(PostgrestException e) {
    if (e.code == '23514') {
      return SupabaseTaskFailureKind.validation;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseTaskFailureKind.denied,
      unknown: SupabaseTaskFailureKind.unknown,
    );
  }
}
