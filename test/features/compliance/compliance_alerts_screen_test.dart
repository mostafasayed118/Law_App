import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/data/fake_compliance_gateway.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/compliance/presentation/compliance_alerts_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpAlerts(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ComplianceAlertsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('compliance alerts screen (v1 queue 2026-08-09)', () {
    testWidgets('lists the synthetic alerts from the fake', (tester) async {
      await pumpAlerts(tester);

      expect(find.text('Compliance alerts'), findsWidgets);
      for (final ComplianceAlert alert
          in FakeComplianceGateway.syntheticAlerts) {
        expect(find.text(alert.title), findsOneWidget);
      }
    });

    testWidgets('renders severity as text label (never color alone)', (
      tester,
    ) async {
      await pumpAlerts(tester);

      expect(find.text('Info'), findsNWidgets(2));
      expect(find.text('Attention'), findsNWidgets(2));
      expect(find.text('Critical'), findsOneWidget);
    });

    testWidgets('renders the local-only demo note', (tester) async {
      await pumpAlerts(tester);

      expect(
        find.text(
          'Demo mode — synthetic alerts only. No real compliance event is shown.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty state renders the localized empty copy', (
      tester,
    ) async {
      await _registerStub(
        <Result<List<ComplianceAlert>>>[
          Result<List<ComplianceAlert>>.success(const <ComplianceAlert>[]),
        ],
      );
      await pumpAlerts(tester);

      expect(find.text('No compliance alerts are available.'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues', (tester) async {
      await _registerStub(<Result<List<ComplianceAlert>>>[
        Result<List<ComplianceAlert>>.failure(_loadFailure),
        Result<List<ComplianceAlert>>.success(
          FakeComplianceGateway.syntheticAlerts,
        ),
      ]);
      await pumpAlerts(tester);

      expect(find.text('Unable to load compliance alerts.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load compliance alerts.'), findsNothing);
      expect(find.text(FakeComplianceGateway.syntheticAlerts.first.title),
          findsOneWidget);
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'alerts_failed',
  userMessage: 'Could not load alerts',
);

Future<void> _registerStub(List<Result<List<ComplianceAlert>>> results) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<ComplianceAlertsGateway>(
    () => _StubComplianceGateway(results),
  );
}

class _StubComplianceGateway implements ComplianceAlertsGateway {
  _StubComplianceGateway(this.results);

  final List<Result<List<ComplianceAlert>>> results;

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts() async {
    return results.removeAt(0);
  }
}