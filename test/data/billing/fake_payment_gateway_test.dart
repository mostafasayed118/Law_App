import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/billing/fake_payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';

void main() {
  group('FakePaymentGateway', () {
    test('is the demo posture, never live', () {
      final FakePaymentGateway gateway = FakePaymentGateway();

      expect(gateway.isLive, isFalse);
      expect(gateway.supportsDemoSimulation, isTrue);
    });

    test(
      'initiate is deterministic and returns a pending https session',
      () async {
        final FakePaymentGateway gateway = FakePaymentGateway();

        final PaymentSession first = (await gateway.initiate(
          'invoice-1',
        )).valueOrNull!;
        final PaymentSession second = (await gateway.initiate(
          'invoice-1',
        )).valueOrNull!;

        expect(first, second);
        expect(first.paymentId, 'demo-payment-invoice-1');
        expect(first.invoiceId, 'invoice-1');
        expect(first.status, PaymentStatus.pending);
        expect(first.checkoutUrl, startsWith('https://'));
        expect(first.checkoutUrl, contains('demo'));
        expect(first.amountCents, 0);
        expect(first.currency, 'EGP');
      },
    );

    test('fetchStatus returns none before any attempt', () async {
      final FakePaymentGateway gateway = FakePaymentGateway();

      final PaymentStatusSnapshot snapshot = (await gateway.fetchStatus(
        'invoice-1',
      )).valueOrNull!;

      expect(snapshot.status, PaymentStatus.none);
      expect(snapshot.paymentId, isNull);
      expect(snapshot.updatedAt, isNull);
    });

    test(
      'simulate drives every supported terminal state deterministically',
      () async {
        final FakePaymentGateway gateway = FakePaymentGateway();
        await gateway.initiate('invoice-1');

        for (final PaymentStatus status in <PaymentStatus>[
          PaymentStatus.pending,
          PaymentStatus.succeeded,
          PaymentStatus.failed,
          PaymentStatus.cancelled,
          PaymentStatus.expired,
        ]) {
          final Result<PaymentStatusSnapshot> result = await gateway.simulate(
            'invoice-1',
            status,
          );
          expect(result.valueOrNull!.status, status);
          expect(
            (await gateway.fetchStatus('invoice-1')).valueOrNull!.status,
            status,
          );
        }
      },
    );

    test(
      'a failed attempt can be retried into a fresh pending attempt',
      () async {
        final FakePaymentGateway gateway = FakePaymentGateway();
        await gateway.initiate('invoice-1');
        await gateway.simulate('invoice-1', PaymentStatus.failed);

        final PaymentSession retry = (await gateway.initiate(
          'invoice-1',
        )).valueOrNull!;

        expect(retry.status, PaymentStatus.pending);
      },
    );

    test('a succeeded attempt is not re-opened by a retry', () async {
      final FakePaymentGateway gateway = FakePaymentGateway();
      await gateway.initiate('invoice-1');
      await gateway.simulate('invoice-1', PaymentStatus.succeeded);

      final PaymentSession retry = (await gateway.initiate(
        'invoice-1',
      )).valueOrNull!;

      expect(retry.status, PaymentStatus.succeeded);
    });

    test('refuses to simulate none or refunded', () async {
      final FakePaymentGateway gateway = FakePaymentGateway();

      await expectLater(
        gateway.simulate('invoice-1', PaymentStatus.none),
        throwsArgumentError,
      );
      await expectLater(
        gateway.simulate('invoice-1', PaymentStatus.refunded),
        throwsArgumentError,
      );
    });

    test('carries no card/PAN/CVV strings', () async {
      final FakePaymentGateway gateway = FakePaymentGateway();
      final PaymentSession session = (await gateway.initiate(
        'invoice-1',
      )).valueOrNull!;
      final String surface =
          '${session.paymentId} ${session.checkoutUrl} ${session.currency}'
              .toLowerCase();

      for (final String forbidden in <String>[
        'card',
        'cvv',
        'pan',
        '4242',
        '5555',
      ]) {
        expect(surface, isNot(contains(forbidden)));
      }
    });
  });
}
