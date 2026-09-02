import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Binds a table SELECT to the app-level client. The builder's `select`
  /// resolves to the raw row list (PostgrestList) — no cast needed.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return Supabase.instance.client.from(table).select(columns);
  }

  /// Binds the D-N6 write RPC to the app-level client: the exact function
  /// name + positional-params shape the migration defines (the
  /// exact-param pin lives in the impl test).
  static Future<Object?> _boundRpc(String fn, Map<String, dynamic>? params) {
    return Supabase.instance.client.rpc(fn, params: params);
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

  /// Maps a PostgrestException to the provider-neutral failure kind.
  /// The stable RLS denial text is the only fragment matched; everything
  /// else is [SupabaseNotificationFailureKind.unknown] with the message
  /// preserved.
  SupabaseNotificationFailureKind _kindFor(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return SupabaseNotificationFailureKind.denied;
    }
    return SupabaseNotificationFailureKind.unknown;
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
