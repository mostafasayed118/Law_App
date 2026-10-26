import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';
import 'package:legalhub/features/billing/presentation/payment_cubit.dart';
import 'package:legalhub/features/billing/presentation/payment_state.dart';

PaymentSession _session(PaymentStatus status) => PaymentSession(
  paymentId: 'pay-1',
  invoiceId: 'invoice-1',
  status: status,
  checkoutUrl: 'https://accept.paymob.com/checkout',
  amountCents: 125000,
  currency: 'EGP',
);

PaymentStatusSnapshot _snapshot(PaymentStatus status) => PaymentStatusSnapshot(
  paymentId: 'pay-1',
  status: status,
  updatedAt: DateTime.utc(2026, 10, 20),
);

class _StubPaymentGateway extends PaymentGateway {
  _StubPaymentGateway({this.live = false});

  final bool live;
  final List<String> initiateCalls = <String>[];
  final List<String> statusCalls = <String>[];
  final List<(String, PaymentStatus)> simulateCalls =
      <(String, PaymentStatus)>[];

  Result<PaymentSession>? initiateResult;
  Completer<Result<PaymentSession>>? initiateCompleter;
  Result<PaymentStatusSnapshot>? statusResult;
  Completer<Result<PaymentStatusSnapshot>>? statusCompleter;
  Result<PaymentStatusSnapshot>? simulateResult;

  @override
  bool get isLive => live;

  @override
  bool get supportsDemoSimulation => !live;

  @override
  Future<Result<PaymentSession>> initiate(String invoiceId) {
    initiateCalls.add(invoiceId);
    if (initiateCompleter != null) {
      return initiateCompleter!.future;
    }
    return Future<Result<PaymentSession>>.value(
      initiateResult ??
          Result<PaymentSession>.success(_session(PaymentStatus.pending)),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId) {
    statusCalls.add(invoiceId);
    if (statusCompleter != null) {
      return statusCompleter!.future;
    }
    return Future<Result<PaymentStatusSnapshot>>.value(
      statusResult ??
          Result<PaymentStatusSnapshot>.success(
            _snapshot(PaymentStatus.pending),
          ),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> simulate(
    String invoiceId,
    PaymentStatus status,
  ) async {
    simulateCalls.add((invoiceId, status));
    return simulateResult ??
        Result<PaymentStatusSnapshot>.success(_snapshot(status));
  }
}

void main() {
  late _StubPaymentGateway gateway;

  setUp(() {
    gateway = _StubPaymentGateway();
  });

  group('PaymentCubit initiate', () {
    blocTest<PaymentCubit, PaymentState>(
      'pay goes initiating → pending on a pending attempt',
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) => cubit.pay('invoice-1'),
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
      ],
      verify: (_) => expect(gateway.initiateCalls, <String>['invoice-1']),
    );

    blocTest<PaymentCubit, PaymentState>(
      'pay maps an already-succeeded initiation to succeeded',
      setUp: () => gateway.initiateResult = Result<PaymentSession>.success(
        _session(PaymentStatus.succeeded),
      ),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) => cubit.pay('invoice-1'),
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.succeeded,
          session: _session(PaymentStatus.succeeded),
        ),
      ],
    );

    blocTest<PaymentCubit, PaymentState>(
      'pay maps an initiation failure to failed + error',
      setUp: () => gateway.initiateResult = Result<PaymentSession>.failure(
        _initiateFailure,
      ),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) => cubit.pay('invoice-1'),
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        const PaymentState(phase: PaymentPhase.failed, error: _initiateFailure),
      ],
    );

    blocTest<PaymentCubit, PaymentState>(
      'duplicate pay while initiating is ignored',
      setUp: () =>
          gateway.initiateCompleter = Completer<Result<PaymentSession>>(),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        final Future<void> first = cubit.pay('invoice-1');
        await cubit.pay('invoice-1');
        gateway.initiateCompleter!.complete(
          Result<PaymentSession>.success(_session(PaymentStatus.pending)),
        );
        await first;
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
      ],
      verify: (_) => expect(gateway.initiateCalls, hasLength(1)),
    );

    blocTest<PaymentCubit, PaymentState>(
      'pay is ignored while pending',
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        await cubit.pay('invoice-1');
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
      ],
      verify: (_) => expect(gateway.initiateCalls, hasLength(1)),
    );
  });

  group('PaymentCubit demo simulation', () {
    for (final MapEntry<PaymentStatus, PaymentPhase> entry
        in <PaymentStatus, PaymentPhase>{
          PaymentStatus.succeeded: PaymentPhase.succeeded,
          PaymentStatus.failed: PaymentPhase.failed,
          PaymentStatus.cancelled: PaymentPhase.cancelled,
          PaymentStatus.expired: PaymentPhase.expired,
        }.entries) {
      blocTest<PaymentCubit, PaymentState>(
        'simulate ${entry.key.name} emits ${entry.value.name}',
        build: () => PaymentCubit(gateway),
        act: (PaymentCubit cubit) async {
          await cubit.pay('invoice-1');
          gateway.simulateResult = Result<PaymentStatusSnapshot>.success(
            _snapshot(entry.key),
          );
          await cubit.simulate(entry.key);
        },
        expect: () => <PaymentState>[
          const PaymentState(phase: PaymentPhase.initiating),
          PaymentState(
            phase: PaymentPhase.pending,
            session: _session(PaymentStatus.pending),
          ),
          PaymentState(phase: entry.value, session: _session(entry.key)),
        ],
        verify: (_) => expect(gateway.simulateCalls, <(String, PaymentStatus)>[
          ('invoice-1', entry.key),
        ]),
      );
    }

    blocTest<PaymentCubit, PaymentState>(
      'simulate is a no-op on a live gateway',
      setUp: () => gateway = _StubPaymentGateway(live: true),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        await cubit.simulate(PaymentStatus.succeeded);
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
      ],
      verify: (_) => expect(gateway.simulateCalls, isEmpty),
    );
  });

  group('PaymentCubit status polling', () {
    blocTest<PaymentCubit, PaymentState>(
      'checkStatus maps a succeeded snapshot',
      setUp: () => gateway.statusResult = Result<PaymentStatusSnapshot>.success(
        _snapshot(PaymentStatus.succeeded),
      ),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        await cubit.checkStatus('invoice-1');
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
        PaymentState(
          phase: PaymentPhase.succeeded,
          session: _session(PaymentStatus.succeeded),
        ),
      ],
      verify: (_) => expect(gateway.statusCalls, <String>['invoice-1']),
    );

    blocTest<PaymentCubit, PaymentState>(
      'checkStatus keeps pending and attaches a transport error',
      setUp: () => gateway.statusResult = Result<PaymentStatusSnapshot>.failure(
        _statusFailure,
      ),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        await cubit.checkStatus('invoice-1');
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
          error: _statusFailure,
        ),
      ],
    );

    blocTest<PaymentCubit, PaymentState>(
      'simulate is ignored while a status check is in flight',
      setUp: () =>
          gateway.statusCompleter = Completer<Result<PaymentStatusSnapshot>>(),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        final Future<void> checking = cubit.checkStatus('invoice-1');
        await cubit.simulate(PaymentStatus.succeeded);
        gateway.statusCompleter!.complete(
          Result<PaymentStatusSnapshot>.success(
            _snapshot(PaymentStatus.pending),
          ),
        );
        await checking;
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
      ],
      verify: (_) => expect(gateway.simulateCalls, isEmpty),
    );

    blocTest<PaymentCubit, PaymentState>(
      'checkStatus maps a no-attempt snapshot to idle',
      setUp: () =>
          gateway.statusResult = const Result<PaymentStatusSnapshot>.success(
            PaymentStatusSnapshot.none(),
          ),
      build: () => PaymentCubit(gateway),
      act: (PaymentCubit cubit) async {
        await cubit.pay('invoice-1');
        await cubit.checkStatus('invoice-1');
      },
      expect: () => <PaymentState>[
        const PaymentState(phase: PaymentPhase.initiating),
        PaymentState(
          phase: PaymentPhase.pending,
          session: _session(PaymentStatus.pending),
        ),
        PaymentState(
          phase: PaymentPhase.idle,
          session: PaymentSession(
            paymentId: 'pay-1',
            invoiceId: 'invoice-1',
            status: PaymentStatus.none,
            checkoutUrl: 'https://accept.paymob.com/checkout',
            amountCents: 125000,
            currency: 'EGP',
          ),
        ),
      ],
    );
  });

  test('exposes the gateway posture flags', () {
    final PaymentCubit demo = PaymentCubit(gateway);
    addTearDown(demo.close);
    expect(demo.isLive, isFalse);
    expect(demo.supportsDemoSimulation, isTrue);

    final PaymentCubit live = PaymentCubit(_StubPaymentGateway(live: true));
    addTearDown(live.close);
    expect(live.isLive, isTrue);
    expect(live.supportsDemoSimulation, isFalse);
  });
}

const AppError _initiateFailure = AppError(
  code: 'payment_initiate_unavailable',
  userMessage: 'Payments are temporarily unavailable.',
);

const AppError _statusFailure = AppError(
  code: 'payment_status_unavailable',
  userMessage: 'Payment status is temporarily unavailable.',
);
