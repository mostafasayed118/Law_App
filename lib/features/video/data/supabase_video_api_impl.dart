import 'dart:convert';

import 'package:legalhub/core/contracts/http_status.dart';
import 'package:legalhub/core/supabase/postgrest_failures.dart';
import 'package:legalhub/core/supabase/supabase_seam.dart';
import 'package:legalhub/core/supabase/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_video_api.dart';

/// A call to the `video-token` Edge Function: name + body → decoded data.
typedef VideoFunctionCaller =
    Future<Object?> Function(String function, Map<String, dynamic> body);

/// A PostgREST RPC call: function name + named params → response.
typedef VideoRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseVideoApi] backed by the Supabase client.
///
/// The only provider-aware file in the video data path. The token comes from
/// the JWT-verified `video-token` Edge Function; reads and lifecycle writes go
/// through the audited RPCs. Callers inject plain function stubs in tests, so
/// no provider instance is required.
class SupabaseVideoApiImpl implements SupabaseVideoApi {
  SupabaseVideoApiImpl({
    VideoFunctionCaller? functionCaller,
    VideoRpcCaller? rpcCaller,
  }) : _functionCaller = functionCaller ?? _boundInvoke,
       _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`.
  factory SupabaseVideoApiImpl.bind() => SupabaseVideoApiImpl();

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

  final VideoFunctionCaller _functionCaller;
  final VideoRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> listSessions({
    required String organizationId,
  }) {
    return _guardRpc(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        SupabaseRpcs.listVideoSessions,
        <String, dynamic>{'p_organization_id': organizationId},
      );
      return _rowsFrom(response.data, SupabaseRpcs.listVideoSessions);
    });
  }

  @override
  Future<String> createSession({
    required String organizationId,
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) {
    return _guardRpc(() async {
      final PostgrestResponse<dynamic> response =
          await _rpcCaller(SupabaseRpcs.createVideoSession, <String, dynamic>{
            'p_organization_id': organizationId,
            'p_matter_id': matterId,
            'p_booking_id': bookingId,
            'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
          });
      final Object? data = response.data;
      if (data is! String || data.isEmpty) {
        throw const SupabaseVideoException(
          kind: SupabaseVideoFailureKind.validation,
          message: 'create_video_session returned no session id.',
        );
      }
      return data;
    });
  }

  @override
  Future<Map<String, dynamic>> fetchToken(String sessionId) async {
    try {
      final Object? data = await _functionCaller(
        SupabaseEdgeFunctions.videoToken,
        <String, dynamic>{'session_id': sessionId},
      );
      if (data is! Map) {
        throw const SupabaseVideoException(
          kind: SupabaseVideoFailureKind.unknown,
          message: 'video-token returned a non-object payload.',
        );
      }
      try {
        return Map<String, dynamic>.from(data);
      } on Object {
        // Deliberately `on Object`: Map.from raises TypeError (an Error) on
        // a malformed key/value shape, and that payload drift must stay a
        // typed malformed response.
        throw const SupabaseVideoException(
          kind: SupabaseVideoFailureKind.unknown,
          message: 'video-token returned a malformed payload.',
        );
      }
    } on SupabaseVideoException {
      rethrow;
    } on FunctionException catch (e) {
      throw SupabaseVideoException(
        kind: _kindForFunction(e),
        message: e.reasonPhrase ?? 'Video provider failure.',
        code: _errorCode(e.details),
      );
    } on Exception {
      throw const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.unavailable,
        message: 'Video provider unavailable.',
      );
    }
  }

  @override
  Future<void> markLive(String id) {
    return _guardRpc(() async {
      await _rpcCaller(SupabaseRpcs.markVideoSessionLive, <String, dynamic>{
        'p_id': id,
      });
    });
  }

  @override
  Future<void> end(String id) {
    return _guardRpc(() async {
      await _rpcCaller(SupabaseRpcs.endVideoSession, <String, dynamic>{
        'p_id': id,
      });
    });
  }

  List<Map<String, dynamic>> _rowsFrom(Object? data, String function) {
    if (data == null) {
      return const <Map<String, dynamic>>[];
    }
    if (data is! List<dynamic>) {
      throw SupabaseVideoException(
        kind: SupabaseVideoFailureKind.unknown,
        message: '$function returned a non-list payload.',
      );
    }
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (final dynamic row in data) {
      if (row is! Map) {
        throw SupabaseVideoException(
          kind: SupabaseVideoFailureKind.unknown,
          message: '$function returned a malformed row.',
        );
      }
      try {
        rows.add(Map<String, dynamic>.from(row));
      } on Object {
        // Deliberately `on Object`: a bad key/value shape raises TypeError
        // (an Error); that row-level drift must stay a typed malformed row.
        throw SupabaseVideoException(
          kind: SupabaseVideoFailureKind.unknown,
          message: '$function returned a malformed row.',
        );
      }
    }
    return rows;
  }

  /// Runs one RPC through the seam's single failure mapping: typed exceptions
  /// pass through, Postgrest failures classify through [_kindForPostgrest], and
  /// any other transport failure becomes unavailable.
  Future<T> _guardRpc<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SupabaseVideoException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseVideoException(
        kind: _kindForPostgrest(e),
        message: e.message,
      );
    } on Exception {
      throw const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.unavailable,
        message: 'Video provider unavailable.',
      );
    }
  }

  /// Classifies a PostgREST failure from the function's own messages. The
  /// RPCs raise `permission denied`, `video session not found`,
  /// `video session is not scheduled`, and `video session has already ended`.
  SupabaseVideoFailureKind _kindForPostgrest(PostgrestException e) {
    final String message = e.message.toLowerCase();
    if (message.contains('not found') ||
        e.code == PostgrestCodes.invalidResponse) {
      return SupabaseVideoFailureKind.notFound;
    }
    if (message.contains('already ended')) {
      return SupabaseVideoFailureKind.sessionEnded;
    }
    if (message.contains('not scheduled')) {
      return SupabaseVideoFailureKind.validation;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseVideoFailureKind.forbidden,
      unknown: SupabaseVideoFailureKind.unknown,
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
  SupabaseVideoFailureKind _kindForFunction(FunctionException e) {
    switch (_errorCode(e.details)) {
      case 'unauthorized':
        return SupabaseVideoFailureKind.unauthorized;
      case 'forbidden':
        return SupabaseVideoFailureKind.forbidden;
      case 'session_not_found':
        return SupabaseVideoFailureKind.notFound;
      case 'session_ended':
        return SupabaseVideoFailureKind.sessionEnded;
      case 'provider_not_configured':
        return SupabaseVideoFailureKind.providerNotConfigured;
      case 'internal_error':
        return SupabaseVideoFailureKind.unknown;
    }
    return switch (e.status) {
      HttpStatusCodes.unauthorized => SupabaseVideoFailureKind.unauthorized,
      HttpStatusCodes.forbidden => SupabaseVideoFailureKind.forbidden,
      HttpStatusCodes.notFound => SupabaseVideoFailureKind.notFound,
      HttpStatusCodes.badRequest => SupabaseVideoFailureKind.validation,
      HttpStatusCodes.conflict =>
        SupabaseVideoFailureKind.providerNotConfigured,
      HttpStatusCodes.internalServerError => SupabaseVideoFailureKind.unknown,
      HttpStatusCodes.badGateway ||
      HttpStatusCodes.serviceUnavailable ||
      HttpStatusCodes.gatewayTimeout => SupabaseVideoFailureKind.unavailable,
      0 => SupabaseVideoFailureKind.unavailable,
      _ => SupabaseVideoFailureKind.unknown,
    };
  }
}
