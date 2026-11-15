import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/features/billing/presentation/invoice_details_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDetails(
    WidgetTester tester, {
    String invoiceId = 'invoice-1',
    PaymentMode mode = PaymentMode.disabled,
  }) async {
    configureDependencies();
    // configureDependencies registers the configured mode; override it with
    // the test's explicit mode.
    await resetServiceLocator();
    configureDependencies();
    if (serviceLocator.isRegistered<PaymentMode>()) {
      serviceLocator.unregister<PaymentMode>();
    }
    serviceLocator.registerSingleton<PaymentMode>(mode);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceDetailsScreen(invoiceId: invoiceId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the invoice metadata without card or payer data', (
    tester,
  ) async {
    await pumpDetails(tester);

    expect(find.text('Invoice details'), findsOneWidget);
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('EGP 1250.00'), findsOneWidget);
    expect(find.text('Matter'), findsOneWidget);
    expect(find.text('Demo acquisition review'), findsOneWidget);
    expect(find.text('Issued'), findsWidgets);
    expect(find.text('Due'), findsOneWidget);
    // D-BI1: no card data / payer identity / billing address on the surface.
    expect(find.byIcon(Icons.credit_card), findsNothing);
    expect(find.textContaining('Card'), findsNothing);
    expect(find.textContaining('CVV'), findsNothing);
  });

  testWidgets('a paid invoice renders no pay action', (tester) async {
    await pumpDetails(tester, invoiceId: 'invoice-2', mode: PaymentMode.demo);
    expect(find.text('INV-2026-0002'), findsOneWidget);
    expect(find.text('Pay'), findsNothing);
  });

  testWidgets('an issued invoice shows the pay action when enabled', (
    tester,
  ) async {
    await pumpDetails(tester, mode: PaymentMode.demo);
    expect(find.text('Pay'), findsOneWidget);
  });

  testWidgets('unknown invoice renders the not-found state', (tester) async {
    await pumpDetails(tester, invoiceId: 'missing');
    expect(find.text('Invoice not found.'), findsOneWidget);
  });
}
