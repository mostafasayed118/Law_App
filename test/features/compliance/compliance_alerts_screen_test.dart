import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/compliance/data/fake_compliance_gateway.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/compliance/presentation/compliance_alerts_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  group('compliance alerts screen (design §4)', () {
    testWidgets('lists the alerts with severity + status text', (tester) async {
      await pumpAlerts(tester);

      expect(find.text('Compliance alerts'), findsOneWidget);
      for (final ComplianceAlert alert
          in FakeComplianceGateway.syntheticAlerts) {
        expect(find.text(alert.title), findsOneWidget);
      }
      expect(find.text('Low · Open'), findsOneWidget);
      expect(find.text('Medium · Open'), findsOneWidget);
      expect(find.text('High · Acknowledged'), findsOneWidget);
      expect(find.text('Critical · Open'), findsOneWidget);
      expect(find.text('Low · Resolved'), findsOneWidget);
    });

    testWidgets('renders severity as icon + text (never color alone)', (
      tester,
    ) async {
      await pumpAlerts(tester);

      expect(find.byIcon(Icons.info_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Critical · Open'), findsOneWidget);
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

    testWidgets('a configured build renders the honest stored note', (
      tester,
    ) async {
      await pumpAlerts(tester, configured: true);

      expect(
        find.text(
          'Alerts are recorded for this organization. '
          'No automated legal verification is performed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty state renders the filtered copy', (tester) async {
      await pumpAlerts(
        tester,
        gateway: _StubComplianceGateway(rows: <ComplianceAlert>[]),
      );

      expect(find.text('No alerts match this filter.'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues', (tester) async {
      await pumpAlerts(
        tester,
        gateway: _StubComplianceGateway(
          rows: <ComplianceAlert>[_row(id: 'a1', title: 'Recovered alert')],
          fetchQueue: <Result<List<ComplianceAlert>>>[
            Result<List<ComplianceAlert>>.failure(_loadFailure),
          ],
        ),
      );

      expect(find.text('Unable to load compliance alerts.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load compliance alerts.'), findsNothing);
      expect(find.text('Recovered alert'), findsOneWidget);
    });

    testWidgets('status filter re-reads with the selected status', (
      tester,
    ) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[
          _row(id: 'a1', title: 'Open alert'),
          _row(id: 'a2', title: 'Resolved alert', status: AlertStatus.resolved),
        ],
      );
      await pumpAlerts(tester, gateway: gateway);

      await tester.tap(find.widgetWithText(FilterChip, 'Resolved'));
      await tester.pumpAndSettle();

      expect(gateway.requestedStatuses.last, AlertStatus.resolved);
      expect(find.text('Resolved alert'), findsOneWidget);
      expect(find.text('Open alert'), findsNothing);
    });

    testWidgets('severity filter re-reads with the selected severity', (
      tester,
    ) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[
          _row(id: 'a1', title: 'Low alert'),
          _row(
            id: 'a2',
            title: 'Critical alert',
            severity: AlertSeverity.critical,
          ),
        ],
      );
      await pumpAlerts(tester, gateway: gateway);

      await tester.tap(find.widgetWithText(FilterChip, 'Critical'));
      await tester.pumpAndSettle();

      expect(gateway.requestedSeverities.last, AlertSeverity.critical);
      expect(find.text('Critical alert'), findsOneWidget);
      expect(find.text('Low alert'), findsNothing);
    });

    testWidgets('the create action only renders for a manager', (tester) async {
      await pumpAlerts(tester);
      expect(find.text('New alert'), findsNothing);

      await pumpAlerts(
        tester,
        gateway: _StubComplianceGateway(rows: <ComplianceAlert>[]),
        canManage: true,
      );
      expect(find.text('New alert'), findsOneWidget);
    });

    testWidgets('create validates the title and submits the draft', (
      tester,
    ) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[],
      );
      await pumpAlerts(tester, gateway: gateway, canManage: true);

      await tester.tap(find.text('New alert'));
      await tester.pumpAndSettle();

      expect(find.text('New compliance alert'), findsOneWidget);

      await tester.tap(find.text('Create alert'));
      await tester.pumpAndSettle();
      expect(find.text('Title must be at least 2 characters.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Filing deadline review',
      );
      await tester.tap(find.byType(DropdownButtonFormField<AlertSeverity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create alert'));
      await tester.pumpAndSettle();

      expect(gateway.createdDrafts, hasLength(1));
      final ComplianceAlertDraft draft = gateway.createdDrafts.single;
      expect(draft.title, 'Filing deadline review');
      expect(draft.organizationId, 'org-1');
      expect(draft.severity, AlertSeverity.high);
      expect(draft.kind, AlertKind.deadline);
      expect(find.text('Alert created.'), findsOneWidget);
      expect(find.text('Filing deadline review'), findsOneWidget);
    });

    testWidgets('any member can acknowledge an open alert', (tester) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[_row(id: 'a1', title: 'Open alert')],
      );
      await pumpAlerts(tester, gateway: gateway);

      await tester.tap(find.text('Open alert'));
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge alert'), findsOneWidget);
      expect(find.text('Resolve alert'), findsNothing);

      await tester.tap(find.text('Acknowledge alert'));
      await tester.pumpAndSettle();

      expect(gateway.acknowledgedId, 'a1');
      expect(find.text('Alert acknowledged.'), findsOneWidget);
      expect(find.text('Low · Acknowledged'), findsOneWidget);
    });

    testWidgets('a manager resolves with the optional note', (tester) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[_row(id: 'a1', title: 'Open alert')],
      );
      await pumpAlerts(tester, gateway: gateway, canManage: true);

      await tester.tap(find.text('Open alert'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Closed after review.');
      await tester.tap(find.text('Resolve alert'));
      await tester.pumpAndSettle();

      expect(gateway.resolvedId, 'a1');
      expect(gateway.lastResolveNote, 'Closed after review.');
      expect(find.text('Alert resolved.'), findsOneWidget);
      expect(find.text('Low · Resolved'), findsOneWidget);
    });

    testWidgets('a manager sees resolve on an acknowledged alert', (
      tester,
    ) async {
      await pumpAlerts(
        tester,
        gateway: _StubComplianceGateway(
          rows: <ComplianceAlert>[
            _row(
              id: 'a1',
              title: 'Acknowledged alert',
              status: AlertStatus.acknowledged,
            ),
          ],
        ),
        canManage: true,
      );

      await tester.tap(find.text('Acknowledged alert'));
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge alert'), findsNothing);
      expect(find.text('Resolve alert'), findsOneWidget);
    });

    testWidgets('a denied action renders the typed denial, no success', (
      tester,
    ) async {
      final _StubComplianceGateway gateway = _StubComplianceGateway(
        rows: <ComplianceAlert>[_row(id: 'a1', title: 'Open alert')],
        actionError: const AppError(
          code: 'compliance_acknowledge_denied',
          userMessage: 'Only an active organization member can acknowledge.',
          kind: AppErrorKind.denied,
        ),
      );
      await pumpAlerts(tester, gateway: gateway);

      await tester.tap(find.text('Open alert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acknowledge alert'));
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to do that.'),
        findsOneWidget,
      );
      expect(find.text('Alert acknowledged.'), findsNothing);
      expect(find.text('Acknowledge alert'), findsOneWidget);
    });
  });
}

final AppError _loadFailure = AppError(
  code: 'compliance_read_failed',
  userMessage: 'Could not load alerts',
);

ComplianceAlert _row({
  required String id,
  required String title,
  AlertKind kind = AlertKind.deadline,
  AlertSeverity severity = AlertSeverity.low,
  AlertStatus status = AlertStatus.open,
  String? description,
  DateTime? dueAt,
  DateTime? acknowledgedAt,
  DateTime? resolvedAt,
}) {
  return ComplianceAlert(
    id: id,
    organizationId: 'org-1',
    title: title,
    description: description,
    kind: kind,
    severity: severity,
    status: status,
    dueAt: dueAt,
    acknowledgedAt: acknowledgedAt,
    resolvedAt: resolvedAt,
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

Future<void> pumpAlerts(
  WidgetTester tester, {
  ComplianceAlertsGateway? gateway,
  bool canManage = false,
  bool configured = false,
}) async {
  await resetServiceLocator();
  if (gateway != null) {
    serviceLocator.registerLazySingleton<ComplianceAlertsGateway>(
      () => gateway,
    );
  }
  if (configured) {
    serviceLocator.registerSingleton<BackendPosture>(
      const BackendPosture(isLocalOnly: false),
    );
  }
  configureDependencies();
  serviceLocator<ActiveOrgStore>().select('org-1');
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ComplianceAlertsScreen(canManage: canManage),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubComplianceGateway implements ComplianceAlertsGateway {
  _StubComplianceGateway({
    required this.rows,
    this.fetchQueue = const <Result<List<ComplianceAlert>>>[],
    this.actionError,
  });

  final List<ComplianceAlert> rows;
  final List<Result<List<ComplianceAlert>>> fetchQueue;
  final AppError? actionError;

  final List<AlertStatus?> requestedStatuses = <AlertStatus?>[];
  final List<AlertSeverity?> requestedSeverities = <AlertSeverity?>[];
  final List<ComplianceAlertDraft> createdDrafts = <ComplianceAlertDraft>[];

  String? acknowledgedId;
  String? resolvedId;
  String? lastResolveNote;

  @override
  Future<Result<List<ComplianceAlert>>> fetchAlerts({
    AlertStatus? status,
    AlertSeverity? severity,
  }) async {
    requestedStatuses.add(status);
    requestedSeverities.add(severity);
    if (fetchQueue.isNotEmpty) {
      return fetchQueue.removeAt(0);
    }
    return Result<List<ComplianceAlert>>.success(
      rows
          .where(
            (ComplianceAlert row) =>
                (status == null || row.status == status) &&
                (severity == null || row.severity == severity),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<String>> create(ComplianceAlertDraft draft) async {
    createdDrafts.add(draft);
    final String id = 'created-${createdDrafts.length}';
    rows.insert(
      0,
      ComplianceAlert(
        id: id,
        organizationId: draft.organizationId,
        matterId: draft.matterId,
        title: draft.title,
        description: draft.description,
        kind: draft.kind,
        severity: draft.severity,
        status: AlertStatus.open,
        dueAt: draft.dueAt,
        createdAt: DateTime.utc(2026, 10, 3),
      ),
    );
    return Result<String>.success(id);
  }

  @override
  Future<Result<void>> acknowledge(String id) async {
    acknowledgedId = id;
    final AppError? error = actionError;
    if (error != null) {
      return Result<void>.failure(error);
    }
    final int index = rows.indexWhere((ComplianceAlert row) => row.id == id);
    rows[index] = _copy(
      rows[index],
      status: AlertStatus.acknowledged,
      acknowledgedAt: DateTime.utc(2026, 10, 4),
    );
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resolve(String id, {String? note}) async {
    resolvedId = id;
    lastResolveNote = note;
    final AppError? error = actionError;
    if (error != null) {
      return Result<void>.failure(error);
    }
    final int index = rows.indexWhere((ComplianceAlert row) => row.id == id);
    rows[index] = _copy(
      rows[index],
      status: AlertStatus.resolved,
      resolvedAt: DateTime.utc(2026, 10, 5),
    );
    return const Result<void>.success(null);
  }

  ComplianceAlert _copy(
    ComplianceAlert row, {
    required AlertStatus status,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
  }) {
    return ComplianceAlert(
      id: row.id,
      organizationId: row.organizationId,
      matterId: row.matterId,
      title: row.title,
      description: row.description,
      kind: row.kind,
      severity: row.severity,
      status: status,
      dueAt: row.dueAt,
      acknowledgedAt: acknowledgedAt ?? row.acknowledgedAt,
      resolvedAt: resolvedAt ?? row.resolvedAt,
      createdAt: row.createdAt,
    );
  }
}
