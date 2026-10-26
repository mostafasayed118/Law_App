import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_compliance_api.dart';

/// A PostgREST RPC call: function name + named params → response.
typedef ComplianceRpcCaller =
    Future<PostgrestResponse<dynamic>> Function(
      String function,
      Map<String, dynamic> params,
    );

/// [SupabaseComplianceApi] backed by the PostgREST client.
///
/// RPC in, plain rows out, PostgrestExceptions mapped to
/// [SupabaseComplianceException]s at the seam. The RPC contracts come from
/// the compliance migration (`list_compliance_alerts` plus the audited
/// create/acknowledge/resolve trio).
class SupabaseComplianceApiImpl implements SupabaseComplianceApi {
  SupabaseComplianceApiImpl({ComplianceRpcCaller? rpcCaller})
    : _rpcCaller = rpcCaller ?? _boundRpc;

  /// Binds to the app-level client after `Supabase.initialize`. Kept a
  /// factory so tests can construct the impl with any callable stub.
  factory SupabaseComplianceApiImpl.bind() => SupabaseComplianceApiImpl();

  static Future<PostgrestResponse<dynamic>> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRpc(function, params);
  }

  final ComplianceRpcCaller _rpcCaller;

  @override
  Future<List<Map<String, dynamic>>> listAlerts({
    required String organizationId,
    String? status,
    String? severity,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response =
          await _rpcCaller('list_compliance_alerts', <String, dynamic>{
            'p_organization_id': organizationId,
            'p_status': status,
            'p_severity': severity,
          });
      final Object? data = response.data;
      if (data == null) {
        return const <Map<String, dynamic>>[];
      }
      if (data is! List<dynamic>) {
        throw const SupabaseComplianceException(
          kind: SupabaseComplianceFailureKind.unknown,
          message: 'list_compliance_alerts returned a non-list payload.',
        );
      }
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
      for (final dynamic row in data) {
        if (row is! Map<String, dynamic>) {
          throw const SupabaseComplianceException(
            kind: SupabaseComplianceFailureKind.unknown,
            message: 'list_compliance_alerts returned a malformed row.',
          );
        }
        rows.add(row);
      }
      return rows;
    });
  }

  @override
  Future<String> createAlert({
    required String organizationId,
    String? matterId,
    required String kind,
    required String severity,
    required String title,
    String? description,
    DateTime? dueAt,
  }) {
    return _guard(() async {
      final PostgrestResponse<dynamic> response =
          await _rpcCaller('create_compliance_alert', <String, dynamic>{
            'p_organization_id': organizationId,
            'p_matter_id': matterId,
            'p_kind': kind,
            'p_severity': severity,
            'p_title': title,
            'p_description': description,
            'p_due_at': dueAt?.toUtc().toIso8601String(),
          });
      final Object? data = response.data;
      if (data is String && data.isNotEmpty) {
        return data;
      }
      throw const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.unknown,
        message: 'create_compliance_alert returned no id.',
      );
    });
  }

  @override
  Future<void> acknowledgeAlert(String id) {
    return _guard(() async {
      await _rpcCaller('acknowledge_compliance_alert', <String, dynamic>{
        'p_id': id,
      });
    });
  }

  @override
  Future<void> resolveAlert(String id, {String? note}) {
    return _guard(() async {
      await _rpcCaller('resolve_compliance_alert', <String, dynamic>{
        'p_id': id,
        'p_note': note,
      });
    });
  }

  /// Runs one RPC through the seam's single failure mapping: typed exceptions
  /// pass through, Postgrest failures classify through [_kindFor], and any
  /// other transport failure becomes a typed unavailable.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SupabaseComplianceException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabaseComplianceException(kind: _kindFor(e), message: e.message);
    } on Exception {
      throw const SupabaseComplianceException(
        kind: SupabaseComplianceFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );
    }
  }

  /// Classifies a Postgrest failure. `23514` is the validation gate; the
  /// denial rule is the shared [isPostgrestDenial]; the RPCs' explicit
  /// `raise exception` texts carry their stable words.
  SupabaseComplianceFailureKind _kindFor(PostgrestException e) {
    if (e.code == '23514') {
      return SupabaseComplianceFailureKind.validation;
    }
    final String message = e.message.toLowerCase();
    if (message.contains('not found')) {
      return SupabaseComplianceFailureKind.notFound;
    }
    if (message.contains('already') ||
        message.contains('required') ||
        message.contains('invalid') ||
        message.contains('too long')) {
      return SupabaseComplianceFailureKind.validation;
    }
    return postgrestKindFor(
      e,
      denied: SupabaseComplianceFailureKind.denied,
      unknown: SupabaseComplianceFailureKind.unknown,
    );
  }
}
