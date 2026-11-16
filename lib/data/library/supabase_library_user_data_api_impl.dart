import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/row_reader.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_library_user_data_api.dart';

/// A PostgREST RPC call: function name + named params → response.
typedef LibraryUserDataRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseLibraryUserDataApi] backed by the PostgREST client.
///
/// Holds the provider import; everything else is rows and typed failures. Each
/// RPC's SQLSTATE becomes a distinct [SupabaseLibraryUserDataFailureKind], which
/// is what lets the UI say "you reached the limit" instead of "something went
/// wrong" for a condition the reader can actually act on.
class SupabaseLibraryUserDataApiImpl implements SupabaseLibraryUserDataApi {
  SupabaseLibraryUserDataApiImpl({LibraryUserDataRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  factory SupabaseLibraryUserDataApiImpl.bind() =>
      SupabaseLibraryUserDataApiImpl();

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final LibraryUserDataRpcCaller _rpcCaller;

  /// SQLSTATEs raised by migration 33. Kept as literals with the SQL beside them
  /// so a change in one place is visibly a change in two.
  static const String _capCode = '54000'; // program_limit_exceeded
  static const String _inputCode = '22023'; // invalid_parameter_value
  static const String _missingCode = 'P0002'; // no_data_found

  @override
  Future<bool> toggleBookmark(String articleId, String? note) {
    return _guardScalar(
      () => _rpcCaller(SupabaseRpcs.toggleLegalBookmark, <String, dynamic>{
        'p_article_id': articleId,
        'p_note': note,
      }),
      (Object? data) => data == true,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listBookmarks({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) {
    return _guardRows(
      () => _rpcCaller(SupabaseRpcs.listMyLegalBookmarks, <String, dynamic>{
        'p_article_id': articleId,
        'p_limit': limit,
        'p_offset': offset,
      }),
    );
  }

  @override
  Future<String> createHighlight({
    required String articleId,
    required int startOffset,
    required int endOffset,
    required String quote,
    required String color,
    String? note,
  }) {
    return _guardScalar(
      () => _rpcCaller(SupabaseRpcs.createLegalHighlight, <String, dynamic>{
        'p_article_id': articleId,
        'p_start_offset': startOffset,
        'p_end_offset': endOffset,
        'p_quote': quote,
        'p_color': color,
        'p_note': note,
      }),
      (Object? data) {
        if (data is String && data.isNotEmpty) {
          return data;
        }
        throw const FormatException('create_legal_highlight returned no id');
      },
    );
  }

  @override
  Future<void> updateHighlight(String id, {String? color, String? note}) {
    return _guardVoid(
      () => _rpcCaller(SupabaseRpcs.updateLegalHighlight, <String, dynamic>{
        'p_id': id,
        'p_color': color,
        'p_note': note,
      }),
    );
  }

  @override
  Future<void> deleteHighlight(String id) {
    return _guardVoid(
      () => _rpcCaller(SupabaseRpcs.deleteLegalHighlight, <String, dynamic>{
        'p_id': id,
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listHighlights({
    String? articleId,
    int limit = 50,
    int offset = 0,
  }) {
    return _guardRows(
      () => _rpcCaller(SupabaseRpcs.listMyLegalHighlights, <String, dynamic>{
        'p_article_id': articleId,
        'p_limit': limit,
        'p_offset': offset,
      }),
    );
  }

  @override
  Future<void> recordReading(String articleId) {
    return _guardVoid(
      () => _rpcCaller(SupabaseRpcs.recordLegalReading, <String, dynamic>{
        'p_article_id': articleId,
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listHistory({
    int limit = 50,
    int offset = 0,
  }) {
    return _guardRows(
      () => _rpcCaller(SupabaseRpcs.listMyLegalHistory, <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
      }),
    );
  }

  @override
  Future<int> clearHistory() {
    return _guardScalar(
      () => _rpcCaller(SupabaseRpcs.clearMyLegalHistory, <String, dynamic>{}),
      (Object? data) => data is num ? data.toInt() : 0,
    );
  }

  Future<List<Map<String, dynamic>>> _guardRows(
    Future<PostgrestResponse<dynamic>> Function() call,
  ) async {
    try {
      final PostgrestResponse<dynamic> response = await call();
      return rowsFrom(response.data);
    } on PostgrestException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: _kindFor(e),
        message: e.message,
      );
    } on FormatException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: SupabaseLibraryUserDataFailureKind.unknown,
        message: e.message,
      );
    }
  }

  Future<T> _guardScalar<T>(
    Future<PostgrestResponse<dynamic>> Function() call,
    T Function(Object? data) parse,
  ) async {
    try {
      final PostgrestResponse<dynamic> response = await call();
      return parse(response.data);
    } on PostgrestException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: _kindFor(e),
        message: e.message,
      );
    } on FormatException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: SupabaseLibraryUserDataFailureKind.unknown,
        message: e.message,
      );
    }
  }

  Future<void> _guardVoid(
    Future<PostgrestResponse<dynamic>> Function() call,
  ) async {
    try {
      await call();
    } on PostgrestException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: _kindFor(e),
        message: e.message,
      );
    } on FormatException catch (e) {
      throw SupabaseLibraryUserDataException(
        kind: SupabaseLibraryUserDataFailureKind.unknown,
        message: e.message,
      );
    }
  }

  SupabaseLibraryUserDataFailureKind _kindFor(PostgrestException e) {
    switch (e.code) {
      case _capCode:
        return SupabaseLibraryUserDataFailureKind.limitReached;
      case _inputCode:
        return SupabaseLibraryUserDataFailureKind.validation;
      case _missingCode:
        return SupabaseLibraryUserDataFailureKind.notFound;
    }
    return postgrestKindFor<SupabaseLibraryUserDataFailureKind>(
      e,
      denied: SupabaseLibraryUserDataFailureKind.denied,
      unknown: SupabaseLibraryUserDataFailureKind.unknown,
    );
  }
}
