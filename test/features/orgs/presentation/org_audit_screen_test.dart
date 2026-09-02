import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/org_audit_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Fake org gateway with a switchable failure for the audit read — keeps the
/// deterministic demo rows for the success path and lets tests force
/// denied/unknown outcomes for the failure paths.
class _SwitchableAuditGateway extends FakeOrganizationGateway {
  OrgFailure? auditFailure;

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    final OrgFailure? failure = auditFailure;
    if (failure != null) {
      return OrgOutcome<List<AuditEntry>>.failure(failure);
    }
    return super.readOrgAudit(organizationId: organizationId);
  }
}

void main() {
  setUp(() async {
    await resetServiceLocator();
    configureDependencies();
  });

  tearDown(() => resetServiceLocator());

  RoleCapability partnerCapabilities() => const RoleCapability(
    canViewHome: true,
    canViewSettings: true,
    canBookConsultation: true,
    canViewAttorneyDiscovery: true,
    canViewMatters: true,
    canViewDocuments: true,
    canViewMessages: true,
    canViewFiles: true,
    canViewAudit: true,
    canViewNotifications: true,
    canViewAlerts: true,
    canViewTasks: true,
    canViewApprovals: true,
    canUseAiResearch: false,
  );

  Widget harness({String? organizationId, Locale locale = const Locale('en')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OrgAuditScreen(
        organizationId: organizationId,
        capabilities: partnerCapabilities(),
      ),
    );
  }

  testWidgets('renders the redacted demo rows', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(organizationId: FakeOrganizationGateway.demoOrganizationId),
    );
    await tester.pumpAndSettle();

    for (final String action in <String>[
      'member:role/change',
      'member:invite',
      'member:suspend',
    ]) {
      expect(find.text(action), findsOneWidget);
    }
    // The demo trail has 2 allowed rows and 1 denied row (fake seed).
    expect(find.text('Allowed'), findsNWidgets(2));
    expect(find.text('Denied'), findsOneWidget);
    // Redacted-only: no export affordances, no share affordances.
    expect(find.byIcon(Icons.ios_share), findsNothing);
    expect(find.byIcon(Icons.upload_outlined), findsNothing);
  });

  testWidgets('shows the honest empty state for a fresh org', (
    WidgetTester tester,
  ) async {
    final OrganizationGateway gateway = serviceLocator<OrganizationGateway>();
    final OrgOutcome<OrganizationSummary> created = await gateway
        .createOrganization(name: 'Fresh Firm');

    await tester.pumpWidget(harness(organizationId: created.valueOrNull!.id));
    await tester.pumpAndSettle();

    expect(find.text('No audit events recorded yet.'), findsOneWidget);
  });

  testWidgets('renders the distinct denied state — never empty success', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(organizationId: 'org-not-in-any-registry'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "You do not have permission to view this organization's audit trail.",
      ),
      findsOneWidget,
    );
    expect(find.text('No audit events recorded yet.'), findsNothing);
  });

  testWidgets('renders the error state and retry reissues', (
    WidgetTester tester,
  ) async {
    final _SwitchableAuditGateway gateway = _SwitchableAuditGateway();
    gateway.auditFailure = const OrgFailure(kind: OrgFailureKind.unknown);
    await resetServiceLocator();
    // Pre-register the stub; configureDependencies() keeps it (its guard
    // only fills unregistered types) and registers the rest.
    serviceLocator.registerLazySingleton<OrganizationGateway>(() => gateway);
    configureDependencies();

    await tester.pumpWidget(
      harness(organizationId: FakeOrganizationGateway.demoOrganizationId),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load the audit trail.'), findsOneWidget);

    gateway.auditFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('member:role/change'), findsOneWidget);
    expect(find.text('Unable to load the audit trail.'), findsNothing);
  });

  testWidgets('renders Arabic RTL without overflow and strings resolve', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سجل التدقيق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
