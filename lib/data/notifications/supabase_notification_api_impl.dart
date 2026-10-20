import 'package:supabase_flutter/supabase_flutter.dart';

import '../postgrest_failures.dart';
import '../supabase_seam.dart';
import 'supabase_notification_api.dart';

/// [SupabaseNotificationApi] backed by the PostgREST client.
///
/// Like [SupabaseBillingApiImpl], this is a data-layer file whose only job
/// is holding the provider import: a table SELECT in, plain map rows out,
/// and PostgrestExceptions mapped to [SupabaseNotificationException]s at the
/// seam.
class SupabaseNotificationApiImpl implements SupabaseNotificationApi {
  SupabaseNotificationApiImpl(this._table, {NotificationRpcCaller? rpc})
    : _rpc = rpc ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseNotificationApiImpl.bind() =>
      SupabaseNotificationApiImpl(_boundTable);

  /// Binds a table SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): newest-first
  /// `.order('server_timestamp')` (served by the `notifications_org_ts`
  /// index) + a hard row cap (audit 2026-09-21, P1). The gateway's
  /// client-side sort stays as the determinism pin on top.
  /// Shared seam bindings ([SupabaseSeam.boundTable] for the
  /// `server_timestamp`-ordered read, [SupabaseSeam.boundRawRpc] for the
  /// D-N6 write RPC — the exact function name + positional-params shape
  /// the migration defines; the exact-param pin lives in the impl test).
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  static Future<Object?> _boundRpc(String fn, Map<String, dynamic>? params) {
    return SupabaseSeam.boundRawRpc(fn, params);
  }

  final NotificationTableCaller _table;
  final NotificationRpcCaller _rpc;

  @override
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      // RLS-scoped (T1 Q2): `notifications_select_org` returns only the
      // caller's active-org rows. Metadata only — the D-N3 column list
      // carries no user-identity/content data (redaction structural, T1 Q1).
      return await _table(
        'notifications',
        'id, category, type, summary, server_timestamp, is_read',
      );
    } on PostgrestException catch (e) {
      throw SupabaseNotificationException(
        kind: _kindFor(e),
        message: e.message,
      );
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the auth
      // impl's defensive-catch precedent).
      throw const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind via the
  /// shared two-kind classifier ([postgrestKindFor] — audit 2026-09-27,
  /// Q-Q1): this impl supplies only its enum values, the match-once logic
  /// lives in `postgrest_failures.dart`.
  SupabaseNotificationFailureKind _kindFor(PostgrestException e) {
    return postgrestKindFor(
      e,
      denied: SupabaseNotificationFailureKind.denied,
      unknown: SupabaseNotificationFailureKind.unknown,
    );
  }

  @override
  Future<int> markNotificationsRead(List<String> ids) async {
    try {
      // D-F1: the exact function + param shape the migration pins — a
      // single uuid[] param. The in-function gate is the sole write
      // authorization; a Postgrest denial maps to the typed kind below.
      final Object? result = await _rpc(
        'mark_notifications_read',
        <String, Object?>{'p_notification_ids': ids},
      );
      if (result is int) {
        return result;
      }
      if (result is num) {
        return result.toInt();
      }
      throw const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.unknown,
        message: 'mark_notifications_read returned a non-numeric result',
      );
    } on PostgrestException catch (e) {
      throw SupabaseNotificationException(
        kind: _kindFor(e),
        message: e.message,
      );
    } on SupabaseNotificationException {
      rethrow;
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam (the read-path
      // defensive-catch precedent).
      throw const SupabaseNotificationException(
        kind: SupabaseNotificationFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }
}
