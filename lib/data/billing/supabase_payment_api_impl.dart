import 'package:legalhub/core/contracts/http_status.dart';
import 'package:legalhub/data/postgrest_failures.dart';
import 'package:legalhub/data/supabase_seam.dart';
import 'package:legalhub/data/supabase_wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_payment_api.dart';

/// [SupabasePaymentApi] backed by the Supabase client.
///
/// The only provider-aware file in the payment data path. Initiation goes
/// through the JWT-verified `paymob-initiate` edge function; status polling
/// goes through the audited `get_invoice_payment_status` RPC. Callers inject
/// plain function stubs in tests, so no provider instance is required.
class SupabasePaymentApiImpl implements SupabasePaymentApi {
  SupabasePaymentApiImpl(this._invoke, this._rpc);

  factory SupabasePaymentApiImpl.bind() =>
      SupabasePaymentApiImpl(_boundInvoke, _boundRpc);

  static Future<Object?> _boundInvoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    final FunctionResponse response = await SupabaseSeam.invokeWithTimeout(
      () => Supabase.instance.client.functions.invoke(function, body: body),
    );
    return response.data;
  }

  static Future<Object?> _boundRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    return SupabaseSeam.boundRawRpc(function, params);
  }

  final PaymentFunctionCaller _invoke;
  final PaymentStatusRpcCaller _rpc;

  @override
  Future<Map<String, dynamic>> initiate(String invoiceId) async {
    try {
      final Object? data = await _invoke(
        SupabaseEdgeFunctions.paymobInitiate,
        <String, dynamic>{'invoice_id': invoiceId},
      );
      return _mapFrom(data);
    } on SupabasePaymentException {
      rethrow;
    } on FunctionException catch (e) {
      throw SupabasePaymentException(
        kind: _kindForFunction(e),
        message: e.reasonPhrase ?? 'Payment provider failure.',
      );
    } on Exception {
      throw const SupabasePaymentException(
        kind: SupabasePaymentFailureKind.providerUnavailable,
        message: 'Payment provider unavailable.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchStatus(String invoiceId) async {
    try {
      final Object? data = await _rpc(
        SupabaseRpcs.getInvoicePaymentStatus,
        <String, dynamic>{'p_invoice_id': invoiceId},
      );
      if (data == null) {
        return null;
      }
      return _mapFrom(data);
    } on SupabasePaymentException {
      rethrow;
    } on PostgrestException catch (e) {
      throw SupabasePaymentException(
        kind: isPostgrestDenial(e)
            ? SupabasePaymentFailureKind.denied
            : SupabasePaymentFailureKind.unknown,
        message: e.message,
      );
    } on Exception {
      throw const SupabasePaymentException(
        kind: SupabasePaymentFailureKind.providerUnavailable,
        message: 'Payment provider unavailable.',
      );
    }
  }

  /// A non-map payload is provider drift, never a silently usable response.
  Map<String, dynamic> _mapFrom(Object? data) {
    if (data is! Map) {
      throw const SupabasePaymentException(
        kind: SupabasePaymentFailureKind.unknown,
        message: 'Malformed payment response.',
      );
    }
    try {
      return Map<String, dynamic>.from(data);
    } on Object {
      // Deliberately `on Object`: Map.from raises TypeError (an Error) on a
      // malformed key/value shape, and that provider drift must stay a typed
      // malformed response rather than propagate as a contract crash.
      throw const SupabasePaymentException(
        kind: SupabasePaymentFailureKind.unknown,
        message: 'Malformed payment response.',
      );
    }
  }

  SupabasePaymentFailureKind _kindForFunction(FunctionException e) {
    if (e.status == HttpStatusCodes.unauthorized ||
        e.status == HttpStatusCodes.forbidden) {
      return SupabasePaymentFailureKind.denied;
    }
    if (e.status == 0 || e.status >= HttpStatusCodes.internalServerError) {
      return SupabasePaymentFailureKind.providerUnavailable;
    }
    return SupabasePaymentFailureKind.unknown;
  }
}
