import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/compliance/presentation/compliance_alert_create_sheet.dart';
import 'package:legalhub/features/compliance/presentation/compliance_alerts_cubit.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  late _StubComplianceGateway gateway;
  late ComplianceAlertsCubit cubit;
  bool? sheetResult;

  setUp(() async {
    await resetServiceLocator();
    gateway = _StubComplianceGateway();
    sheetResult = null;
    serviceLocator.registerLazySingleton<ComplianceAlertsGateway>(
      () => gateway,
    );
    configureDependencies();
    cubit = ComplianceAlertsCubit(gateway);
  });

  tearDown(() async {
    await cubit.close();
    await resetServiceLocator();
  });

  Future<void> openSheet(WidgetTester tester, {bool withOrg = true}) async {
    if (withOrg) {
      serviceLocator<ActiveOrgStore>().select('org-1');
    }
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
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () async {
                  sheetResult = await showComplianceAlertCreateSheet(
                    context,
                    cubit: cubit,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(WidgetTester tester, String title) async {
    await tester.enterText(find.byType(TextFormField).first, title);
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create alert'));
    await tester.tap(find.text('Create alert'));
    await tester.pumpAndSettle();
  }

  group('ComplianceAlertCreateSheet', () {
    testWidgets('renders the required fields and blocks an empty submit', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('New compliance alert'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Kind'), findsOneWidget);
      expect(find.text('Severity'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
      expect(find.text('Create alert'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tapSubmit(tester);

      expect(find.text('Title must be at least 2 characters.'), findsOneWidget);
      expect(gateway.createAttempts, 0);
      expect(find.text('New compliance alert'), findsOneWidget);
    });

    testWidgets('refuses to submit without an active organization', (
      tester,
    ) async {
      await openSheet(tester, withOrg: false);

      expect(
        find.text('Select an organization before creating an alert.'),
        findsOneWidget,
      );
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create alert'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('submits the draft and closes with success', (tester) async {
      await openSheet(tester);

      await enterTitle(tester, '  Filing deadline review  ');
      await tester.enterText(
        find.byType(TextFormField).last,
        ' Needs partner review ',
      );
      await tester.tap(find.byType(DropdownButtonFormField<AlertKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retention').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<AlertSeverity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      expect(gateway.createdDrafts, hasLength(1));
      final ComplianceAlertDraft draft = gateway.createdDrafts.single;
      expect(draft.organizationId, 'org-1');
      expect(draft.title, 'Filing deadline review');
      expect(draft.kind, AlertKind.retention);
      expect(draft.severity, AlertSeverity.high);
      expect(draft.description, 'Needs partner review');
      expect(find.text('New compliance alert'), findsNothing);
      expect(sheetResult, isTrue);
    });

    testWidgets('renders a typed failure inline and keeps submit available', (
      tester,
    ) async {
      gateway.createFailures.add(
        const AppError(
          code: 'compliance_create_unavailable',
          userMessage: 'offline',
          kind: AppErrorKind.unavailable,
        ),
      );
      await openSheet(tester);

      await enterTitle(tester, 'Filing deadline review');
      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('The service is temporarily unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('New compliance alert'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create alert'),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('a thrown create re-enables submit and a retry lands (N1)', (
      tester,
    ) async {
      gateway.throwNextCreate = true;
      await openSheet(tester);

      await enterTitle(tester, 'Filing deadline review');
      await tapSubmit(tester);

      expect(gateway.createAttempts, 1);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('New compliance alert'), findsOneWidget);
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create alert'),
      );
      expect(submit.onPressed, isNotNull);

      await tapSubmit(tester);

      expect(gateway.createAttempts, 2);
      expect(gateway.createdDrafts, hasLength(1));
      expect(find.text('New compliance alert'), findsNothing);
      expect(sheetResult, isTrue);
    });
  });
}

class _StubComplianceGateway implements ComplianceAlertsGateway {
  final List<ComplianceAlertDraft> createdDrafts = <ComplianceAlertDraft>[];
  final List<AppError> createFailures = <AppError>[];
  bool throwNextCreate = false;
  int createAttempts = 0;

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  }) async {
    return Result<List<ComplianceAlert>>.success(const <ComplianceAlert>[]);
  }

  @override
  Future<Result<String>> create(ComplianceAlertDraft draft) async {
    createAttempts += 1;
    if (throwNextCreate) {
      throwNextCreate = false;
      throw StateError('create blew up');
    }
    if (createFailures.isNotEmpty) {
      return Result<String>.failure(createFailures.removeAt(0));
    }
    createdDrafts.add(draft);
    return Result<String>.success('created-${createdDrafts.length}');
  }

  @override
  Future<Result<void>> acknowledge(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> resolve(String id, {String? note}) async {
    throw UnimplementedError();
  }
}
