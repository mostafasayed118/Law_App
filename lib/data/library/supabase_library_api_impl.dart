import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/row_reader.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_library_api.dart';

/// A PostgREST RPC call: function name + named params → response.
typedef LibraryRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseLibraryApi] backed by the PostgREST client.
///
/// A data-layer file whose only job is holding the provider import: RPC in,
/// plain rows out, and PostgrestExceptions mapped to
/// [SupabaseLibraryException]s at the seam. Every call carries the app-wide
/// deadline through [SupabaseSeam.boundRpc].
class SupabaseLibraryApiImpl implements SupabaseLibraryApi {
  SupabaseLibraryApiImpl({LibraryRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a factory
  /// so tests can construct the impl with any callable stub.
  factory SupabaseLibraryApiImpl.bind() => SupabaseLibraryApiImpl();

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final LibraryRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> listDocuments({
    String? category,
    int limit = 50,
    int offset = 0,
  }) {
    return _guard(
      () => _rpcCaller(SupabaseRpcs.listLegalDocuments, <String, dynamic>{
        'p_category': category,
        'p_limit': limit,
        'p_offset': offset,
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getDocument(
    String id, {
    int articleLimit = 200,
  }) {
    return _guard(
      () => _rpcCaller(SupabaseRpcs.getLegalDocument, <String, dynamic>{
        'p_id': id,
        'p_article_limit': articleLimit,
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getArticle(String id) {
    return _guard(
      () => _rpcCaller(SupabaseRpcs.getLegalArticle, <String, dynamic>{
        'p_id': id,
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String? category,
    int limit = 20,
    int offset = 0,
  }) {
    return _guard(
      () => _rpcCaller(SupabaseRpcs.searchLegalLibrary, <String, dynamic>{
        'p_query': query,
        'p_category': category,
        'p_limit': limit,
        'p_offset': offset,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> _guard(
    Future<PostgrestResponse<dynamic>> Function() call,
  ) async {
    try {
      final PostgrestResponse<dynamic> response = await call();
      return rowsFrom(response.data);
    } on PostgrestException catch (e) {
      throw SupabaseLibraryException(kind: _kindFor(e), message: e.message);
    } on FormatException catch (e) {
      throw SupabaseLibraryException(
        kind: SupabaseLibraryFailureKind.unknown,
        message: e.message,
      );
    }
  }

  /// `22023` is the `invalid_parameter_value` the search RPC raises for an
  /// over-length query; it must not be flattened into `unknown`, or the UI
  /// would offer a retry that can never succeed.
  SupabaseLibraryFailureKind _kindFor(PostgrestException e) {
    if (e.code == '22023') {
      return SupabaseLibraryFailureKind.validation;
    }
    return postgrestKindFor<SupabaseLibraryFailureKind>(
      e,
      denied: SupabaseLibraryFailureKind.denied,
      unknown: SupabaseLibraryFailureKind.unknown,
    );
  }
}
