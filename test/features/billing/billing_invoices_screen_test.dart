import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/billing/data/fake_billing_gateway.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/presentation/billing_invoices_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpInvoices(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BillingInvoicesScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

  group('billing invoices screen (billing slice D-BI5)', () {
    testWidgets('lists the synthetic invoice metadata from the fake (D-BI5)', (
      tester,
    ) async {
      await pumpInvoices(tester);

      expect(find.text('Invoices'), findsOneWidget);
      for (final Invoice invoice in FakeBillingGateway.syntheticInvoices) {
        expect(find.text(invoice.invoiceNumber), findsOneWidget);
      }
      expect(find.text('EGP 1250.00 · Issued'), findsOneWidget);
      expect(find.text('EGP 875.00 · Paid'), findsOneWidget);
    });

    testWidgets('renders metadata only — no body, no pay action (D-BI1/D-11)', (
      tester,
    ) async {
      await pumpInvoices(tester);

      expect(find.text('Pay'), findsNothing);
      expect(find.text('Pay now'), findsNothing);
      expect(find.byIcon(Icons.payment), findsNothing);
      expect(find.byIcon(Icons.credit_card), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders the local-only demo note (D-BI4)', (tester) async {
      await pumpInvoices(tester);

      expect(
        find.text(
          'Demo mode — synthetic invoice metadata only. No real '
          'payments are shown.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty list renders the localized empty state', (tester) async {
      await _registerStub(<Result<List<Invoice>>>[
        Result<List<Invoice>>.success(const <Invoice>[]),
      ]);
      await pumpInvoices(tester);

      expect(find.text('No invoices are available.'), findsOneWidget);
      expect(find.text('INV-2026-0001'), findsNothing);
    });

    testWidgets('failure renders the error state with a working retry', (
      tester,
    ) async {
      await _registerStub(<Result<List<Invoice>>>[
        Result<List<Invoice>>.failure(_loadFailure),
        Result<List<Invoice>>.success(FakeBillingGateway.syntheticInvoices),
      ]);
      await pumpInvoices(tester);

      expect(find.text('Unable to load invoices.'), findsOneWidget);
      expect(find.text('INV-2026-0001'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load invoices.'), findsNothing);
      expect(find.text('INV-2026-0001'), findsOneWidget);
    });

    testWidgets('rows carry the matter reference and issued date (D-BI5)', (
      tester,
    ) async {
      await pumpInvoices(tester);

      expect(
        find.text(
          'Demo acquisition review · ${dateLabel(DateTime(2026, 7, 1))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Commercial lease consultation · '
          '${dateLabel(DateTime(2026, 6, 15))}',
        ),
        findsOneWidget,
      );
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'invoices_failed',
  userMessage: 'Could not load invoices',
);

/// Registers a stub billing gateway in the locator so the screen resolves the
/// queued results instead of the dev fake.
Future<void> _registerStub(List<Result<List<Invoice>>> results) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<BillingGateway>(
    () => _StubBillingGateway(results),
  );
}

/// Hand-rolled gateway stub: a queue of results (mirrors the billing cubit
/// test's stub — timing-independent immediate resolution).
class _StubBillingGateway implements BillingGateway {
  _StubBillingGateway(this.results);

  final List<Result<List<Invoice>>> results;

  @override
  Future<Result<List<Invoice>>> fetchInvoices() async {
    return results.removeAt(0);
  }
}
