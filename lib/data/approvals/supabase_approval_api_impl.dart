import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_approval_api.dart';

/// A PostgREST RPC call: function name + named params → response.
typedef ApprovalRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseApprovalApi] backed by the PostgREST client.
///
/// RPC in, plain rows out, PostgrestExceptions mapped to
/// [SupabaseApprovalException]s at the seam. The RPC contracts come from the
/// approvals migration (`list_approval_requests` plus the audited
/// create/decide/cancel trio).
class SupabaseApprovalApiImpl implements SupabaseApprovalApi {
  SupabaseApprovalApiImpl({ApprovalRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseApprovalApiImpl.bind() => SupabaseApprovalApiImpl();

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final ApprovalRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> listApprovals({
    required String organizationId,
    String? status,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response = await _rpcCaller(
        'list_approval_requests',
        <String, dynamic>{
          'p_organization_id': organizationId,
          'p_status': status,
        },
      );
      final Object? data = response.data;
      if (data == null) {
        return const <Map<String, dynamic>>[];
      }
      if (data is! List<dynamic>) {
        throw const SupabaseApprovalException(
          kind: SupabaseApprovalFailureKind.unknown,
          message: 'list_approval_requests returned a non-list payload.',
        );
      }
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      for (final dynamic row in data) {
        if (row is! Map<String, dynamic>) {
          throw const SupabaseApprovalException(
            kind: SupabaseApprovalFailureKind.unknown,
            message: 'list_approval_requests returned a malformed row.',
          );
        }
        rows.add(row);
      }
      return rows;
    });
  }

  @override
  Future<String> createApproval({
    required String organizationId,
    String? matterId,
    required String title,
    required String kind,
    String? description,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response =
          await _rpcCaller('create_approval_request', <String, dynamic>{
            'p_organization_id': organizationId,
            'p_matter_id': matterId,
            'p_title': title,
            'p_kind': kind,
            'p_description': description,
          });
      final Object? data = response.data;
      if (data is String && data.isNotEmpty) {
        return data;
      }
      throw const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.unknown,
        message: 'create_approval_request returned no id.',
      );
    });
  }

  @override
  Future<void> decideApproval(
    String id, {
    required String decision,
    String? note,
  }) {
    return _guard(() async {
      await _rpcCaller('decide_approval_request', <String, dynamic>{
        'p_id': id,
        'p_decision': decision,
        'p_note': note,
      });
    });
  }

  @override
  Future<void> cancelApproval(String id) {
    return _guard(() async {
      await _rpcCaller('cancel_approval_request', <String, dynamic>{
        'p_id': id,
      });
    });
  }

  /// Runs one RPC through the seam's single failure mapping: typed exceptions
  /// pass through, Postgrest failures classify through [_kindFor], and any
  /// other transport failure becomes a typed unavailable.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SupabaseApprovalException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseApprovalException(kind: _kindFor(e), message: e.message);
    } on Object {
      throw const SupabaseApprovalException(
        kind: SupabaseApprovalFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Classifies a Postgrest failure. `23514` is the validation gate;
  /// the denial rule is the shared [isPostgrestDenial]; the RPCs' explicit
  /// `raise exception` texts (`not found`, `is not pending`, `note is
  /// required`) carry their stable words.
  SupabaseApprovalFailureKind _kindFor(PostgrestException e) {
    if (e.code == '23514') {
      return SupabaseApprovalFailureKind.validation;
    }
    final String message = e.message.toLowerCase();
    if (message.contains('not found')) {
      return SupabaseApprovalFailureKind.notFound;
    }
    if (message.contains('required') ||
        message.contains('not pending') ||
        message.contains('invalid')) {
      return SupabaseApprovalFailureKind.validation;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseApprovalFailureKind.denied,
      unknown: SupabaseApprovalFailureKind.unknown,
    );
  }
}
