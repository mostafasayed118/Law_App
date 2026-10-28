import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';
import 'payment_state.dart';

/// Owns one invoice-payment attempt for the modal sheet.
///
/// [pay] initiates (or reuses) the server-side attempt; [checkStatus] polls
/// the authoritative status; [simulate] drives the demo-only fake. Duplicate
/// taps are ignored while an initiation/status call is in flight. Polling is
/// live-only (the demo has no server to poll) and runs every [pollInterval]
/// for at most [pollTimeout]; it is cancelled on a terminal status and when
/// the cubit closes.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(
    this._gateway, {
    this.pollInterval = const Duration(seconds: 5),
    this.pollTimeout = const Duration(minutes: 2),
  }) : super(const PaymentState());

  final PaymentGateway _gateway;
  final Duration pollInterval;
  final Duration pollTimeout;

  bool _busy = false;
  bool _checking = false;
  String? _invoiceId;
  Timer? _pollTimer;
  Duration _pollElapsed = Duration.zero;

  bool get isLive => _gateway.isLive;

  bool get supportsDemoSimulation =>
      _gateway.supportsDemoSimulation && !_gateway.isLive;

  /// Initiates a payment attempt. Blocked while initiating/pending and while
  /// another call is in flight.
  Future<void> pay(String invoiceId) async {
    if (isClosed || _busy) {
      return;
    }
    if (state.phase == PaymentPhase.initiating ||
        state.phase == PaymentPhase.pending) {
      return;
    }
    _busy = true;
    _invoiceId = invoiceId;
    emit(const PaymentState(phase: PaymentPhase.initiating));
    final Result<PaymentSession> result;
    try {
      result = await _gateway.initiate(invoiceId);
    } catch (_) {
      // The initiating phase is itself an in-flight guard, so a thrown
      // gateway has to land on the failure phase — otherwise every retry
      // would be refused by the phase check below.
      if (!isClosed) {
        emit(
          const PaymentState(
            phase: PaymentPhase.failed,
            error: AppError(
              code: 'payment_initiate_failed',
              userMessage: 'Unable to start the payment. Please try again.',
            ),
          ),
        );
      }
      return;
    } finally {
      _busy = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<PaymentSession>(value: final PaymentSession session):
        final PaymentPhase phase = _phaseFor(session.status);
        emit(PaymentState(phase: phase, session: session));
        if (_phaseIsTerminal(phase)) {
          stopPolling();
        }
      case Failure<PaymentSession>(error: final AppError error):
        emit(PaymentState(phase: PaymentPhase.failed, error: error));
    }
  }

  /// Polls the authoritative status. A failure keeps the current phase and
  /// attaches the error (a status outage is not a payment failure).
  Future<void> checkStatus(String invoiceId) async {
    if (isClosed || _checking || _busy) {
      return;
    }
    _checking = true;
    _invoiceId = invoiceId;
    final Result<PaymentStatusSnapshot> result;
    try {
      result = await _gateway.fetchStatus(invoiceId);
    } finally {
      // Reset on throw too: the next poll tick must be able to run.
      _checking = false;
    }
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<PaymentStatusSnapshot>(value: final snapshot):
        final PaymentPhase phase = _phaseFor(snapshot.status);
        emit(PaymentState(phase: phase, session: _sessionWith(snapshot)));
        if (_phaseIsTerminal(phase)) {
          stopPolling();
        }
      case Failure<PaymentStatusSnapshot>(error: final AppError error):
        emit(
          PaymentState(
            phase: state.phase,
            session: state.session,
            error: error,
          ),
        );
    }
  }

  /// Demo-only terminal simulation.
  Future<void> simulate(PaymentStatus status) async {
    final String? invoiceId = _invoiceId;
    if (isClosed ||
        _busy ||
        _checking ||
        invoiceId == null ||
        !supportsDemoSimulation ||
        status == PaymentStatus.none ||
        status == PaymentStatus.refunded) {
      return;
    }
    _busy = true;
    try {
      final Result<PaymentStatusSnapshot> result = await _gateway.simulate(
        invoiceId,
        status,
      );
      if (isClosed) {
        return;
      }
      switch (result) {
        case Success<PaymentStatusSnapshot>(value: final snapshot):
          final PaymentPhase phase = _phaseFor(snapshot.status);
          emit(PaymentState(phase: phase, session: _sessionWith(snapshot)));
          if (_phaseIsTerminal(phase)) {
            stopPolling();
          }
        case Failure<PaymentStatusSnapshot>(error: final AppError error):
          emit(
            PaymentState(
              phase: state.phase,
              session: state.session,
              error: error,
            ),
          );
      }
    } finally {
      _busy = false;
    }
  }

  /// Starts live status polling for [invoiceId] (no-op in demo).
  void startPolling(String invoiceId) {
    stopPolling();
    if (isClosed || !_gateway.isLive) {
      return;
    }
    _pollElapsed = Duration.zero;
    _pollTimer = Timer.periodic(pollInterval, (Timer timer) {
      _pollElapsed += pollInterval;
      if (_pollElapsed > pollTimeout || isClosed) {
        stopPolling();
        return;
      }
      unawaited(checkStatus(invoiceId));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollElapsed = Duration.zero;
  }

  PaymentSession? _sessionWith(PaymentStatusSnapshot snapshot) {
    final PaymentSession? current = state.session;
    if (current == null) {
      return null;
    }
    return PaymentSession(
      paymentId: snapshot.paymentId ?? current.paymentId,
      invoiceId: current.invoiceId,
      status: snapshot.status,
      checkoutUrl: current.checkoutUrl,
      amountCents: current.amountCents,
      currency: current.currency,
    );
  }

  PaymentPhase _phaseFor(PaymentStatus status) => switch (status) {
    PaymentStatus.none => PaymentPhase.idle,
    PaymentStatus.pending => PaymentPhase.pending,
    PaymentStatus.succeeded => PaymentPhase.succeeded,
    PaymentStatus.failed => PaymentPhase.failed,
    PaymentStatus.cancelled => PaymentPhase.cancelled,
    PaymentStatus.expired => PaymentPhase.expired,
    // The sheet has no refund copy; a refunded attempt is terminal and the
    // invoice remains settled server-side, so it is treated as failed here.
    PaymentStatus.refunded => PaymentPhase.failed,
  };

  bool _phaseIsTerminal(PaymentPhase phase) => switch (phase) {
    PaymentPhase.succeeded ||
    PaymentPhase.failed ||
    PaymentPhase.cancelled ||
    PaymentPhase.expired => true,
    PaymentPhase.idle ||
    PaymentPhase.initiating ||
    PaymentPhase.pending => false,
  };

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
