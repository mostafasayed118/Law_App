import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';

/// Deterministic demo payment gateway.
///
/// The demo is the product posture for the payments slice: initiation always
/// produces the same pending session for an invoice, status is whatever the
/// caller simulated (or `none` before an attempt), and nothing leaves the
/// process. The fake checkout URL is clearly non-provider, is never opened in
/// demo, and contains no card/PAN/CVV data. The session amount is zero because
/// the demo never charges; the sheet renders the invoice's own amount.
class FakePaymentGateway extends PaymentGateway {
  final Map<String, PaymentStatus> _statuses = <String, PaymentStatus>{};

  static final DateTime _demoUpdatedAt = DateTime.utc(2026, 1, 1);

  @override
  bool get isLive => false;

  @override
  bool get supportsDemoSimulation => true;

  @override
  Future<Result<PaymentSession>> initiate(String invoiceId) async {
    final PaymentStatus? current = _statuses[invoiceId];
    // A terminal non-success attempt may be retried: mirror the server's
    // "failed/expired/cancelled attempts allow a fresh pending attempt"
    // lifecycle. A succeeded/refunded attempt is not re-opened.
    if (current == null ||
        current == PaymentStatus.failed ||
        current == PaymentStatus.cancelled ||
        current == PaymentStatus.expired) {
      _statuses[invoiceId] = PaymentStatus.pending;
    }
    return Result<PaymentSession>.success(
      PaymentSession(
        paymentId: 'demo-payment-$invoiceId',
        invoiceId: invoiceId,
        status: _statuses[invoiceId]!,
        checkoutUrl: 'https://demo.paymob.example/checkout/$invoiceId',
        amountCents: 0,
        currency: 'EGP',
      ),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId) async {
    final PaymentStatus status = _statuses[invoiceId] ?? PaymentStatus.none;
    if (status == PaymentStatus.none) {
      return const Result<PaymentStatusSnapshot>.success(
        PaymentStatusSnapshot.none(),
      );
    }
    return Result<PaymentStatusSnapshot>.success(
      PaymentStatusSnapshot(
        paymentId: 'demo-payment-$invoiceId',
        status: status,
        updatedAt: _demoUpdatedAt,
      ),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> simulate(
    String invoiceId,
    PaymentStatus status,
  ) async {
    if (status == PaymentStatus.none || status == PaymentStatus.refunded) {
      throw ArgumentError.value(
        status,
        'status',
        'Not a demo-simulable status',
      );
    }
    _statuses[invoiceId] = status;
    return Result<PaymentStatusSnapshot>.success(
      PaymentStatusSnapshot(
        paymentId: 'demo-payment-$invoiceId',
        status: status,
        updatedAt: _demoUpdatedAt,
      ),
    );
  }
}
