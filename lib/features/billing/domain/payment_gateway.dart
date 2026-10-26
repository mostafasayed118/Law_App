import 'package:legalhub/core/errors/result.dart';
import 'payment_session.dart';
import 'payment_status.dart';

/// Payment-attempt boundary (payments slice).
///
/// [isLive] is the honesty flag for the UI: only the Supabase-backed gateway
/// returns true, so a live build without a configured Supabase env (which
/// falls back to the fake) never claims a real charge is possible.
///
/// `simulate` is demo-only. It has a default that throws [UnsupportedError] so
/// production gateways inherit the refusal without boilerplate; the fake
/// overrides it and reports [supportsDemoSimulation] = true.
abstract class PaymentGateway {
  bool get isLive;

  bool get supportsDemoSimulation;

  Future<Result<PaymentSession>> initiate(String invoiceId);

  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId);

  Future<Result<PaymentStatusSnapshot>> simulate(
    String invoiceId,
    PaymentStatus status,
  ) {
    throw UnsupportedError(
      'Payment simulation is only available on a demo gateway.',
    );
  }
}
