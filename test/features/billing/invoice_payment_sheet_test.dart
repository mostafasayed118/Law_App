import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/billing/data/fake_payment_gateway.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';
import 'package:legalhub/features/billing/presentation/invoice_payment_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';

final Invoice _issuedInvoice = Invoice(
  id: 'invoice-1',
  matterRef: 'Demo acquisition review',
  invoiceNumber: 'INV-2026-0001',
  amountCents: 125000,
  currency: 'EGP',
  status: InvoiceStatus.issued,
  issuedAt: DateTime(2026, 7, 1),
  dueAt: DateTime(2026, 7, 31),
);

class _RecordingLauncher implements CheckoutLauncher {
  final List<Uri> opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

class _ExpiredInitiateGateway extends PaymentGateway {
  @override
  bool get isLive => false;

  @override
  bool get supportsDemoSimulation => true;

  @override
  Future<Result<PaymentSession>> initiate(String invoiceId) async {
    return Result<PaymentSession>.success(
      PaymentSession(
        paymentId: 'pay-1',
        invoiceId: invoiceId,
        status: PaymentStatus.expired,
        checkoutUrl: null,
        amountCents: 125000,
        currency: 'EGP',
      ),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId) async {
    return Result<PaymentStatusSnapshot>.success(
      PaymentStatusSnapshot(
        paymentId: 'pay-1',
        status: PaymentStatus.expired,
        updatedAt: DateTime.utc(2026, 10, 20),
      ),
    );
  }
}

class _LiveStubGateway extends PaymentGateway {
  Result<PaymentStatusSnapshot> statusResult =
      Result<PaymentStatusSnapshot>.success(
        PaymentStatusSnapshot(
          paymentId: 'pay-1',
          status: PaymentStatus.pending,
          updatedAt: DateTime.utc(2026, 10, 20),
        ),
      );
  int statusCalls = 0;

  @override
  bool get isLive => true;

  @override
  bool get supportsDemoSimulation => false;

  @override
  Future<Result<PaymentSession>> initiate(String invoiceId) async {
    return Result<PaymentSession>.success(
      PaymentSession(
        paymentId: 'pay-1',
        invoiceId: invoiceId,
        status: PaymentStatus.pending,
        checkoutUrl: 'https://accept.paymob.com/unifiedcheckout/?publicKey=pub',
        amountCents: 125000,
        currency: 'EGP',
      ),
    );
  }

  @override
  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId) async {
    statusCalls++;
    return statusResult;
  }
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required PaymentGateway gateway,
    required CheckoutLauncher launcher,
    Future<void> Function()? onSettled,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => unawaited(
                showInvoicePaymentSheet(
                  context: context,
                  invoice: _issuedInvoice,
                  gateway: gateway,
                  launcher: launcher,
                  onSettled: onSettled ?? () async {},
                ),
              ),
              child: const Text('Open payment'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open payment'));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }

  group('InvoicePaymentSheet — demo', () {
    testWidgets('opens in pending with the demo note and simulate controls', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
      );

      expect(find.text('Invoice payment'), findsOneWidget);
      expect(find.text('Waiting for payment confirmation…'), findsOneWidget);
      expect(find.text('Demo only — no real charge.'), findsOneWidget);
      expect(find.text('Simulate success'), findsOneWidget);
      expect(find.text('Simulate failure'), findsOneWidget);
      expect(find.text('Simulate cancel'), findsOneWidget);
      expect(find.text('Open checkout'), findsNothing);
      expect(find.text('Check status'), findsNothing);

      await closeSheet(tester);
    });

    testWidgets('simulate success shows the success state and settles once', (
      tester,
    ) async {
      int settled = 0;
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
        onSettled: () async => settled++,
      );

      await tester.tap(find.text('Simulate success'));
      await tester.pumpAndSettle();

      expect(find.text('Payment successful'), findsOneWidget);
      expect(
        find.text(
          'Demo payment simulated — no charge was made and the invoice is unchanged.',
        ),
        findsOneWidget,
      );
      expect(settled, 1);

      await closeSheet(tester);
      expect(settled, 1);
    });

    testWidgets('simulate failure shows the failed state and does not settle', (
      tester,
    ) async {
      int settled = 0;
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
        onSettled: () async => settled++,
      );

      await tester.tap(find.text('Simulate failure'));
      await tester.pumpAndSettle();

      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('The payment did not go through. You can try again.'),
        findsOneWidget,
      );
      expect(settled, 0);

      await closeSheet(tester);
    });

    testWidgets('retry after a demo failure returns to the pending state', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
      );

      await tester.tap(find.text('Simulate failure'));
      await tester.pumpAndSettle();
      expect(find.text('Payment failed'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Waiting for payment confirmation…'), findsOneWidget);
      expect(find.text('Simulate success'), findsOneWidget);

      await closeSheet(tester);
    });

    testWidgets('simulate cancel shows the cancelled state', (tester) async {
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
      );

      await tester.tap(find.text('Simulate cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Payment cancelled'), findsOneWidget);
      expect(
        find.text('The payment was cancelled. You can try again.'),
        findsOneWidget,
      );

      await closeSheet(tester);
    });

    testWidgets('an expired attempt shows the expired state', (tester) async {
      await pumpSheet(
        tester,
        gateway: _ExpiredInitiateGateway(),
        launcher: _RecordingLauncher(),
      );

      expect(find.text('Payment expired'), findsOneWidget);
      expect(
        find.text('The checkout session expired. You can start a new payment.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      await closeSheet(tester);
    });

    testWidgets('has no card fields anywhere', (tester) async {
      await pumpSheet(
        tester,
        gateway: FakePaymentGateway(),
        launcher: _RecordingLauncher(),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('CVV'), findsNothing);
      expect(find.textContaining('Card number'), findsNothing);

      await closeSheet(tester);
    });
  });

  group('InvoicePaymentSheet — live', () {
    testWidgets('pending shows hosted-checkout actions and opens the URL', (
      tester,
    ) async {
      final _RecordingLauncher launcher = _RecordingLauncher();
      await pumpSheet(tester, gateway: _LiveStubGateway(), launcher: launcher);

      expect(find.text('Waiting for payment confirmation…'), findsOneWidget);
      expect(
        find.text(
          'Complete the payment in the secure hosted checkout, then come '
          'back to this screen.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open checkout'), findsOneWidget);
      expect(find.text('Check status'), findsOneWidget);
      expect(find.text('Simulate success'), findsNothing);

      await tester.tap(find.text('Open checkout'));
      await tester.pump();

      expect(launcher.opened, hasLength(1));
      expect(launcher.opened.single.scheme, 'https');
      expect(launcher.opened.single.host, 'accept.paymob.com');

      await closeSheet(tester);
    });

    testWidgets('check status maps a succeeded snapshot and settles', (
      tester,
    ) async {
      final _LiveStubGateway gateway = _LiveStubGateway()
        ..statusResult = Result<PaymentStatusSnapshot>.success(
          PaymentStatusSnapshot(
            paymentId: 'pay-1',
            status: PaymentStatus.succeeded,
            updatedAt: DateTime.utc(2026, 10, 20),
          ),
        );
      int settled = 0;
      await pumpSheet(
        tester,
        gateway: gateway,
        launcher: _RecordingLauncher(),
        onSettled: () async => settled++,
      );

      await tester.tap(find.text('Check status'));
      await tester.pumpAndSettle();

      expect(find.text('Payment successful'), findsOneWidget);
      expect(gateway.statusCalls, greaterThanOrEqualTo(1));
      expect(settled, 1);

      await closeSheet(tester);
    });
  });
}
