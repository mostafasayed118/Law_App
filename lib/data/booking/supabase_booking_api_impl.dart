import 'package:supabase_flutter/supabase_flutter.dart';

import '../postgrest_failures.dart';
import '../supabase_seam.dart';
import 'supabase_booking_api.dart';

/// A PostgREST table SELECT: table name + columns → raw map rows.
///
/// Plain function type so tests inject a closure and the impl is the only
/// file that ever touches provider types (the `MatterTableCaller` pattern).
typedef BookingTableCaller =
    Future<List<Map<String, dynamic>>> Function(String table, String columns);

/// A PostgREST RPC call: function name + named params → response.
///
/// Mirrors `TaskRpcCaller` from the task seam.
typedef BookingRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseBookingApi] backed by the PostgREST client.
///
/// Like [SupabaseTaskApiImpl], this is a data-layer file whose only job is
/// holding the provider import: a bounded table SELECT in, plain map rows out,
/// the booking RPC response as a single map row, and PostgrestExceptions
/// mapped to [SupabaseBookingException]s at the seam.
class SupabaseBookingApiImpl implements SupabaseBookingApi {
  SupabaseBookingApiImpl(this._table, {BookingRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseBookingApiImpl.bind() => SupabaseBookingApiImpl(_boundTable);

  /// Binds the slot SELECT to the app-level client via the shared bounded
  /// binding (`list_query_guards.dart`): ascending `starts_at` (availability
  /// window) plus a hard row cap.
  static Future<List<Map<String, dynamic>>> _boundTable(
    String table,
    String columns,
  ) {
    return SupabaseSeam.boundTable(table, columns);
  }

  /// Binds the audited booking RPC to the app-level client.
  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  /// The slot columns the [BookingSlot] VO needs.
  static const String _slotColumns = 'id, starts_at, duration_minutes';

  final BookingTableCaller _table;
  final BookingRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> fetchSlots() async {
    try {
      // RLS-scoped: `consultation_slots_select_available` returns only
      // authenticated-visible, active, unclaimed rows.
      return await _table('consultation_slots', _slotColumns);
    } on PostgrestException catch (e) {
      throw SupabaseBookingException(kind: _kindFor(e), message: e.message);
    } on Object {
      // A non-Postgrest provider failure (network/transport) is a typed
      // unavailable, never a raw exception across the seam.
      throw const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> bookConsultation({
    required String slotId,
    required String category,
    String? topic,
    String? attorneyRef,
  }) async {
    // `book_consultation` is the ONLY write path (no INSERT policy or grant
    // on `consultations` or `consultation_slots`). The RPC trims and caps
    // the optional text fields in-function and returns the persisted
    // non-PII projection.
    try {
      final PostgrestResponse<dynamic> response =
          await _rpcCaller('book_consultation', <String, dynamic>{
            'p_slot_id': slotId,
            'p_category': category,
            'p_topic': topic,
            'p_attorney_ref': attorneyRef,
          });
      final Object? data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const SupabaseBookingException(
          kind: SupabaseBookingFailureKind.unknown,
          message: 'book_consultation returned no row.',
        );
      }
      return data;
    } on SupabaseBookingException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseBookingException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Maps a PostgrestException to the provider-neutral failure kind.
  ///
  /// The RPC's validation gates raise `check_violation` (surfaced as SQLSTATE
  /// digits `23514`); a lost slot claim raises `unique_violation` (`23505`);
  /// the shared denial rule covers the in-function `permission denied` text
  /// and RLS denials. Everything else is unknown.
  SupabaseBookingFailureKind _kindFor(PostgrestException e) {
    if (e.code == '23514') {
      return SupabaseBookingFailureKind.validation;
    }
    if (e.code == '23505') {
      return SupabaseBookingFailureKind.slotUnavailable;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseBookingFailureKind.denied,
      unknown: SupabaseBookingFailureKind.unknown,
    );
  }
}
