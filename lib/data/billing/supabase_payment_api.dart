/// Provider-neutral payment seam (payments slice).
///
/// The only surface the payment gateway talks to: an edge-function invoke for
/// initiation and a raw RPC for status polling. Provider types never cross
/// this boundary; failures arrive as typed [SupabasePaymentException]s.
library;

/// Invokes an edge function with a JSON body and returns its decoded data.
typedef PaymentFunctionCaller =
    Future<Object?> Function(String function, Map<String, dynamic> body);

/// Invokes an RPC with named params and returns its decoded data.
typedef PaymentStatusRpcCaller =
    Future<Object?> Function(String function, Map<String, dynamic> params);

/// Typed reasons a payment call can fail.
enum SupabasePaymentFailureKind {
  /// The caller may not pay this invoice (auth/RLS/function 401/403).
  denied,

  /// The provider or function is unreachable or failed at transport level.
  providerUnavailable,

  /// An unspecified or malformed response.
  unknown,
}

/// A typed failure crossing the [SupabasePaymentApi] seam.
class SupabasePaymentException implements Exception {
  const SupabasePaymentException({required this.kind, required this.message});

  final SupabasePaymentFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabasePaymentException(${kind.name}): $message';
}

/// The payments slice's server contract.
abstract interface class SupabasePaymentApi {
  /// Calls `paymob-initiate` with `{invoice_id}`; returns the edge payload
  /// (`payment_id`, `status`, `checkout_url`, `amount_cents`, `currency`).
  Future<Map<String, dynamic>> initiate(String invoiceId);

  /// Calls `get_invoice_payment_status` with `{p_invoice_id}`; returns null
  /// when the invoice has no payment attempt yet.
  Future<Map<String, dynamic>?> fetchStatus(String invoiceId);
}
