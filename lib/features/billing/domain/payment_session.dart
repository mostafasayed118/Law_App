import 'package:equatable/equatable.dart';

import 'payment_status.dart';

/// One initiated payment attempt, as returned by the edge function.
///
/// [checkoutUrl] is the provider-hosted checkout URL (nullable when the
/// provider did not return one). It is never logged; the redactor treats it as
/// a sensitive value.
class PaymentSession extends Equatable {
  const PaymentSession({
    required this.paymentId,
    required this.invoiceId,
    required this.status,
    required this.checkoutUrl,
    required this.amountCents,
    required this.currency,
  });

  final String paymentId;
  final String invoiceId;
  final PaymentStatus status;
  final String? checkoutUrl;
  final int amountCents;
  final String currency;

  @override
  List<Object?> get props => <Object?>[
    paymentId,
    invoiceId,
    status,
    checkoutUrl,
    amountCents,
    currency,
  ];
}

/// The status-poll result. A null [paymentId]/[updatedAt] with [PaymentStatus.none]
/// means the invoice has no payment attempt yet (the RPC's null response).
class PaymentStatusSnapshot extends Equatable {
  const PaymentStatusSnapshot({
    required this.paymentId,
    required this.status,
    required this.updatedAt,
  });

  /// No attempt exists for the invoice.
  const PaymentStatusSnapshot.none()
    : paymentId = null,
      status = PaymentStatus.none,
      updatedAt = null;

  final String? paymentId;
  final PaymentStatus status;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => <Object?>[paymentId, status, updatedAt];
}
