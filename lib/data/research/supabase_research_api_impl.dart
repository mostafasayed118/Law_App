import 'dart:convert';

import 'package:legalhub/core/contracts/http_status.dart';
import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:legalhub/features/research/domain/research_wire_codes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_research_api.dart';

/// A call to the `research-analyze` Edge Function: name + body → decoded data.
typedef ResearchFunctionCaller =
    Future<Object?> Function(String function, Map<String, dynamic> body);

/// A PostgREST RPC call: function name + named params → response.
typedef ResearchRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseResearchApi] backed by the Supabase client.
///
/// The only provider-aware file in the research data path. Analysis goes
/// through the JWT-verified `research-analyze` Edge Function; reads go through
/// `list_research_runs` / `list_research_findings`. Callers inject plain
/// function stubs in tests, so no provider instance is required.
class SupabaseResearchApiImpl implements SupabaseResearchApi {
  SupabaseResearchApiImpl({
    ResearchFunctionCaller? functionCaller,
    ResearchRpcCaller? rpcCaller,
  }) : _functionCaller = functionCaller ?? _boundInvoke,
       _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseResearchApiImpl.bind() => SupabaseResearchApiImpl();

  static Future<Object?> _boundInvoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    final FunctionResponse response = await SupabaseSeam.invokeWithTimeout(
      () => Supabase.instance.client.functions.invoke(function, body: body),
    );
    return response.data;
  }

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final ResearchFunctionCaller _functionCaller;
  final ResearchRpcCaller _rpcCaller;

  @override
  Future<Map<String, dynamic>> analyze({
    required String organizationId,
    String? matterId,
    required List<String> documentIds,
    required String question,
  }) async {
    try {
      final Object? data = await _functionCaller(
        SupabaseEdgeFunctions.researchAnalyze,
        <String, dynamic>{
          'organization_id': organizationId,
          'matter_id': matterId,
          'document_ids': documentIds,
          'question': question,
        },
      );
      if (data is! Map) {
        throw const SupabaseResearchException(
          kind: SupabaseResearchFailureKind.invalidResponse,
          message: 'research-analyze returned a non-object payload.',
        );
      }
      try {
        return Map<String, dynamic>.from(data);
      } on Object {
        // Deliberately `on Object`: Map.from raises TypeError (an Error) on
        // a malformed key/value shape, and that payload drift must stay a
        // typed invalid response.
        throw const SupabaseResearchException(
          kind: SupabaseResearchFailureKind.invalidResponse,
          message: 'research-analyze returned a malformed payload.',
        );
      }
    } on SupabaseResearchException {
      rethrow;
    } on FunctionException catch (e) {
      throw SupabaseResearchException(
        kind: _kindForFunction(e),
        message: e.reasonPhrase ?? 'Research provider failure.',
        code: _errorCode(e.details),
      );
    } on Exception {
      throw const SupabaseResearchException(
        kind: SupabaseResearchFailureKind.providerUnavailable,
        message: 'Research provider unavailable.',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listRuns({
    required String organizationId,
    required int limit,
  }) {
    return _guardRpc(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        SupabaseRpcs.listResearchRuns,
        <String, dynamic>{'p_organization_id': organizationId},
      );
      final List<Map<String, dynamic>> rows = _rowsFrom(
        response.data,
        SupabaseRpcs.listResearchRuns,
      );
      final int capped = limit < 0 ? 0 : limit;
      return rows.take(capped).toList(growable: false);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> listFindings(String runId) {
    return _guardRpc(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        SupabaseRpcs.listResearchFindings,
        <String, dynamic>{'p_run_id': runId},
      );
      return _rowsFrom(response.data, SupabaseRpcs.listResearchFindings);
    });
  }

  List<Map<String, dynamic>> _rowsFrom(Object? data, String function) {
    if (data == null) {
      return const <Map<String, dynamic>>[];
    }
    if (data is! List<dynamic>) {
      throw SupabaseResearchException(
        kind: SupabaseResearchFailureKind.unknown,
        message: '$function returned a non-list payload.',
      );
    }
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (final dynamic row in data) {
      if (row is! Map) {
        throw SupabaseResearchException(
          kind: SupabaseResearchFailureKind.unknown,
          message: '$function returned a malformed row.',
        );
      }
      try {
        rows.add(Map<String, dynamic>.from(row));
      } on Object {
        // Deliberately `on Object`: a bad key/value shape raises TypeError
        // (an Error); that row-level drift must stay a typed malformed row.
        throw SupabaseResearchException(
          kind: SupabaseResearchFailureKind.unknown,
          message: '$function returned a malformed row.',
        );
      }
    }
    return rows;
  }

  /// Runs one read RPC through the seam's single failure mapping: typed
  /// exceptions pass through, Postgrest failures classify through
  /// [_kindForPostgrest], and any other transport failure becomes unavailable.
  Future<T> _guardRpc<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SupabaseResearchException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseResearchException(
        kind: _kindForPostgrest(e),
        message: e.message,
      );
    } on Exception {
      throw const SupabaseResearchException(
        kind: SupabaseResearchFailureKind.providerUnavailable,
        message: 'Research provider unavailable.',
      );
    }
  }

  /// Classifies a PostgREST read failure. The RPCs' `not found` gate maps to
  /// [SupabaseResearchFailureKind.notFound]; the shared denial rule maps to
  /// forbidden; everything else stays unknown for the gateway to classify.
  SupabaseResearchFailureKind _kindForPostgrest(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('not found') ||
        e.code == PostgrestCodes.invalidResponse) {
      return SupabaseResearchFailureKind.notFound;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseResearchFailureKind.forbidden,
      unknown: SupabaseResearchFailureKind.unknown,
    );
  }

  /// Reads the function's `{ "error": "<code>" }` body from either a decoded
  /// map or a JSON string (the Functions client's `details` is dynamic).
  String? _errorCode(Object? details) {
    if (details is Map) {
      final Object? error = details['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    if (details is String && details.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(details);
        if (decoded is Map) {
          final Object? error = decoded['error'];
          if (error is String && error.isNotEmpty) {
            return error;
          }
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// The wire code is authoritative; the status is the fallback when a proxy
  /// strips the JSON body.
  SupabaseResearchFailureKind _kindForFunction(FunctionException e) {
    switch (_errorCode(e.details)) {
      case ResearchWireCodes.unauthorized:
        return SupabaseResearchFailureKind.unauthorized;
      case ResearchWireCodes.forbidden:
        return SupabaseResearchFailureKind.forbidden;
      case ResearchWireCodes.invalidRequest:
        return SupabaseResearchFailureKind.invalidRequest;
      case ResearchWireCodes.contextTooLarge:
        return SupabaseResearchFailureKind.contextTooLarge;
      case ResearchWireCodes.providerNotConfigured:
        return SupabaseResearchFailureKind.providerNotConfigured;
      case ResearchWireCodes.providerUnavailable:
        return SupabaseResearchFailureKind.providerUnavailable;
      case ResearchWireCodes.invalidResponse:
        return SupabaseResearchFailureKind.invalidResponse;
    }
    return switch (e.status) {
      HttpStatusCodes.unauthorized => SupabaseResearchFailureKind.unauthorized,
      HttpStatusCodes.forbidden => SupabaseResearchFailureKind.forbidden,
      HttpStatusCodes.badRequest => SupabaseResearchFailureKind.invalidRequest,
      HttpStatusCodes.conflict =>
        SupabaseResearchFailureKind.providerNotConfigured,
      HttpStatusCodes.unprocessableEntity =>
        SupabaseResearchFailureKind.contextTooLarge,
      HttpStatusCodes.internalServerError =>
        SupabaseResearchFailureKind.invalidResponse,
      HttpStatusCodes.badGateway ||
      HttpStatusCodes.serviceUnavailable ||
      HttpStatusCodes.gatewayTimeout =>
        SupabaseResearchFailureKind.providerUnavailable,
      0 => SupabaseResearchFailureKind.providerUnavailable,
      _ => SupabaseResearchFailureKind.unknown,
    };
  }
}
