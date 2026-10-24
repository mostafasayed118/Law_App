/// Payment-attempt lifecycle (payments slice).
///
/// Exactly the `payments.status` CHECK set plus [none] for "the invoice has
/// no attempt yet" (the status RPC returns null in that case). Provider drift
/// outside this set must fail loudly at the gateway mapping boundary.
enum PaymentStatus {
  none,
  pending,
  succeeded,
  failed,
  cancelled,
  expired,
  refunded;

  /// Parses the wire value returned by the payment RPC/edge function.
  static PaymentStatus fromWire(String value) => switch (value) {
    'pending' => pending,
    'succeeded' => succeeded,
    'failed' => failed,
    'cancelled' => cancelled,
    'expired' => expired,
    'refunded' => refunded,
    _ => throw FormatException('Unmapped payment status: $value'),
  };
}
