import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';

/// The payment sheet's view phase (payments slice).
enum PaymentPhase {
  idle,
  initiating,
  pending,
  succeeded,
  failed,
  cancelled,
  expired,
}

/// Immutable state of the payment sheet.
class PaymentState extends Equatable {
  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.session,
    this.error,
  });

  final PaymentPhase phase;
  final PaymentSession? session;

  /// A transport/initiation failure (not a provider terminal status). The
  /// sheet renders `paymentUnavailable` when this is non-null.
  final AppError? error;

  @override
  List<Object?> get props => <Object?>[phase, session, error];
}
