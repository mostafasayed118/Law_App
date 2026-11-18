import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/localization/locale_cubit.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/app/theme/theme_cubit.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/data/auth/fake_auth_gateway.dart';
import 'package:legalhub/data/local/in_memory_locale_store.dart';
import 'package:legalhub/data/local/in_memory_theme_mode_store.dart';
import 'package:legalhub/data/orgs/fake_membership_repository.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/approvals/presentation/approval_create_sheet.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/conflicts/domain/conflict_disclosure.dart';
import 'package:legalhub/features/conflicts/presentation/conflict_check_cubit.dart';
import 'package:legalhub/features/conflicts/presentation/conflict_check_screen.dart';
import 'package:legalhub/features/conflicts/presentation/conflict_take_action_sheet.dart';
import 'package:legalhub/features/conflicts/presentation/disclosure_cubit.dart';
import 'package:legalhub/features/conflicts/presentation/disclosure_wizard_screen.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/tasks/presentation/task_create_sheet.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Phase 0 RED: both conflict routes and the disclosure wizard state machine
/// are missing at the base commit. These assertions use only existing strings,
/// so the file compiles and fails on the unmodified app.
void main() {
  late FakeAuthGateway gateway;
  late AuthCubit authCubit;
  late LocaleCubit localeCubit;
  late ThemeCubit themeCubit;
  GoRouter? router;

  setUp(() async {
    configureDependencies();
    gateway = FakeAuthGateway();
    authCubit = AuthCubit(
      gateway,
      InMemoryErrorReporter(),
      FakeMembershipRepository(),
      FakeOrganizationGateway(),
    );
    localeCubit = LocaleCubit(InMemoryLocaleStore());
    await localeCubit.load();
    themeCubit = ThemeCubit(InMemoryThemeModeStore());
    await themeCubit.load();
    await authCubit.startDemoSession();
    serviceLocator<ActiveOrgStore>().select('org-demo-1');
  });

  tearDown(() async {
    router?.dispose();
    router = null;
    await authCubit.close();
    await localeCubit.close();
    await themeCubit.close();
    await gateway.dispose();
    await resetServiceLocator();
  });

  Widget harness() => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<AuthCubit>.value(value: authCubit),
      BlocProvider<LocaleCubit>.value(value: localeCubit),
      BlocProvider<ThemeCubit>.value(value: themeCubit),
    ],
    child: MaterialApp.router(
      routerConfig: router!,
      theme: ThemeData.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );

  Future<void> open(WidgetTester tester, String path) async {
    router = createAppRouter(authCubit, initialLocation: path);
    tester.view.physicalSize = const Size(411, 867);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets('disclosure route opens step 1', (WidgetTester tester) async {
    await open(tester, '/conflicts/disclose');
    expect(find.text('Identify Matter'), findsOneWidget);
  });

  testWidgets('conflict check route opens the search screen', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/check');
    expect(find.text('Conflict Check'), findsWidgets);
    expect(find.text('Check New Party or Entity'), findsOneWidget);
  });

  testWidgets('wizard advances and steps back without losing the draft', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');
    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('Party Identification'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Identify Matter'), findsOneWidget);
  });

  testWidgets('wizard runs a real check and requires certification to submit', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');
    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Demo party');
    await tester.enterText(fields.at(1), 'EG');
    await tester.tap(find.text('Add Party'));
    await tester.pumpAndSettle();
    expect(find.text('Identified Parties (1)'), findsOneWidget);

    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('Analysis Findings'), findsOneWidget);
    // No invented confidence score or percentage is ever rendered.
    expect(find.textContaining('%'), findsNothing);

    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();
    expect(find.text('Final Review'), findsOneWidget);

    final Finder submit = find.text('Submit Disclosure');
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: submit, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(of: submit, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('check screen records only real searches and watchlist adds', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/check');
    await tester.enterText(find.byType(TextFormField), 'Demo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final ConflictCheckCubit cubit = tester
        .element(
          find
              .descendant(
                of: find.byType(ConflictCheckScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<ConflictCheckCubit>();
    expect(cubit.state.recents, hasLength(1));
    expect(cubit.state.recents.single.query, 'Demo');
    expect(cubit.state.watchlist, isEmpty);

    cubit.addToWatchlist('Demo entity');
    expect(cubit.state.watchlist, hasLength(1));
    expect(cubit.state.watchlist.single.name, 'Demo entity');
    await tester.pumpAndSettle();

    cubit.clearHistory();
    expect(cubit.state.recents, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('take action sheet has two live and two disabled procedures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComplianceTakeActionSheet(
            alert: ComplianceAlert(
              id: 'alert-demo-1',
              organizationId: 'org-demo-1',
              matterId: 'matter-demo-1',
              title: 'Demo conflict alert',
              kind: AlertKind.conflict,
              severity: AlertSeverity.high,
              status: AlertStatus.open,
              createdAt: DateTime.utc(2026, 11, 17),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final String label in <String>[
      'Initiate Ethical Wall',
      'Request Waiver',
      'Escalate to Partner',
      'File Regulatory Disclosure',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.textContaining('Requires the ethical-wall feature'),
      findsOneWidget,
    );
    expect(find.textContaining('Requires the filings feature'), findsOneWidget);

    final List<ListTile> tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .toList();
    expect(tiles, hasLength(4));
    expect(tiles[0].enabled, isFalse);
    expect(tiles[1].enabled, isTrue);
    expect(tiles[2].enabled, isTrue);
    expect(tiles[3].enabled, isFalse);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'wizard shows only real gateway matches and the static recommendation',
    (WidgetTester tester) async {
      final MatterGateway matters = serviceLocator<MatterGateway>();
      final List<Matter> rows = switch (await matters.fetchMatters()) {
        Success<List<Matter>>(value: final List<Matter> value) => value,
        _ => const <Matter>[],
      };
      await open(tester, '/conflicts/disclose');
      await tester.tap(find.text('Demo acquisition review'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        rows.first.assignedAttorneyName,
      );
      await tester.tap(find.text('Add Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Match found — review required'), findsOneWidget);
      // The matching attorney belongs to the selected matter, so the honest
      // derived kind is "Indirect Link" (not an invented direct conflict).
      expect(find.textContaining('Indirect Link'), findsWidgets);
      expect(
        find.text(
          'Obtain a waiver or establish an ethical wall prior to onboarding.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue to Review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Proposed Resolution'), findsOneWidget);
    },
  );

  testWidgets('check screen filters and watchlist add use real search rows', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/check');
    await tester.enterText(find.byType(TextFormField), 'Demo');
    await tester.tap(find.text('START SEARCH'));
    await tester.pumpAndSettle();
    for (final String chip in <String>[
      'Client',
      'Adverse Party',
      'Related Entity',
    ]) {
      await tester.tap(find.text(chip));
      await tester.pumpAndSettle();
    }
    final Finder watch = find.text('Add to watchlist');
    expect(watch, findsWidgets);
    await tester.tap(watch.first);
    await tester.pumpAndSettle();
    final ConflictCheckCubit cubit = tester
        .element(
          find
              .descendant(
                of: find.byType(ConflictCheckScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<ConflictCheckCubit>();
    expect(cubit.state.watchlist, hasLength(1));
  });

  testWidgets('live procedures open the existing approval and task sheets', (
    WidgetTester tester,
  ) async {
    final List<Matter> matterRows =
        switch (await serviceLocator<MatterGateway>().fetchMatters()) {
          Success<List<Matter>>(value: final List<Matter> value) => value,
          _ => const <Matter>[],
        };
    final ComplianceAlert alert = ComplianceAlert(
      id: 'alert-demo-2',
      organizationId: 'org-demo-1',
      matterId: matterRows.first.id,
      title: 'Demo conflict alert',
      kind: AlertKind.conflict,
      severity: AlertSeverity.high,
      status: AlertStatus.open,
      createdAt: DateTime.utc(2026, 11, 17),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () =>
                  showComplianceTakeActionSheet(context, alert: alert),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request Waiver'));
    await tester.pumpAndSettle();
    expect(find.byType(ApprovalCreateSheet), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escalate to Partner'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCreateSheet), findsOneWidget);
  });

  testWidgets('wizard help, search, edit and success paths', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();

    final Finder search = find.byType(TextFormField).first;
    await tester.enterText(search, 'zzzz-no-match');
    await tester.pumpAndSettle();
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await tester
        .element(
          find
              .descendant(
                of: find.byType(DisclosureWizardScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<DisclosureCubit>()
        .loadMatters();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Demo party');
    await tester.tap(find.text('Add Party'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Identify Matter'), findsOneWidget);

    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final DisclosureCubit wizard = tester
        .element(
          find
              .descendant(
                of: find.byType(DisclosureWizardScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<DisclosureCubit>();
    expect(wizard.state.step, DisclosureStep.review);
    expect(wizard.state.draft.certified, isTrue);
    await wizard.submit();
    await tester.pumpAndSettle();
    expect(
      wizard.state.step,
      DisclosureStep.success,
      reason:
          'status=${wizard.state.submitStatus} error=${wizard.state.submitError} '
          'org=${serviceLocator<ActiveOrgStore>().activeOrganizationId}',
    );
    expect(find.text('Disclosure submitted.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'check screen renders every real result group and relative times',
    (WidgetTester tester) async {
      await open(tester, '/conflicts/check');
      final ConflictCheckCubit cubit = tester
          .element(
            find
                .descendant(
                  of: find.byType(ConflictCheckScreen),
                  matching: find.byType(ListView),
                )
                .first,
          )
          .read<ConflictCheckCubit>();
      await cubit.search(
        'Layla',
        l10n: AppLocalizations.of(
          tester.element(find.byType(ConflictCheckScreen)),
        ),
      );
      await tester.pumpAndSettle();
      final Finder watchButtons = find.text('Add to watchlist');
      expect(watchButtons, findsWidgets);
      await tester.tap(watchButtons.first);
      await tester.pumpAndSettle();
      await cubit.search(
        'Demo',
        l10n: AppLocalizations.of(
          tester.element(find.byType(ConflictCheckScreen)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.account_circle_outlined));
      await tester.pumpAndSettle();

      cubit.emit(
        cubit.state.copyWith(
          recents: <ConflictRecent>[
            ConflictRecent(
              query: 'Layla',
              resultCount: 1,
              at: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
            ConflictRecent(
              query: 'Demo',
              resultCount: 2,
              at: DateTime.now().subtract(const Duration(hours: 5)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 min', skipOffstage: false), findsWidgets);
      expect(find.textContaining('5 h', skipOffstage: false), findsWidgets);
      await tester.tap(find.text('Layla').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('wizard role dropdown, party removal and empty matter search', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');
    final Finder search = find.byType(TextFormField).first;
    await tester.enterText(search, 'no-such-matter');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();
    await tester
        .element(
          find
              .descendant(
                of: find.byType(DisclosureWizardScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<DisclosureCubit>()
        .loadMatters();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ConflictPartyRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Co-Counsel').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Demo party');
    await tester.tap(find.text('Add Party'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Party'));
    await tester.pumpAndSettle();
    expect(find.text('Identified Parties (0)'), findsOneWidget);
  });

  testWidgets('close exits the wizard and edit buttons jump to their step', (
    WidgetTester tester,
  ) async {
    await open(tester, '/conflicts/disclose');
    final DisclosureCubit wizard = tester
        .element(
          find
              .descendant(
                of: find.byType(DisclosureWizardScreen),
                matching: find.byType(ListView),
              )
              .first,
        )
        .read<DisclosureCubit>();
    await wizard.searchMatters('no-such-matter');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await open(tester, '/conflicts/disclose');
    await tester.tap(find.text('Demo acquisition review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Demo party');
    await tester.tap(find.text('Add Party'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Party Identification'), findsOneWidget);
    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').at(2));
    await tester.pumpAndSettle();
    expect(find.text('Analysis Findings'), findsOneWidget);
  });

  testWidgets('alerts summary counts come from the real alert list', (
    WidgetTester tester,
  ) async {
    final ComplianceAlertsGateway gateway =
        serviceLocator<ComplianceAlertsGateway>();
    final List<ComplianceAlert> alerts = switch (await gateway.fetchAlerts()) {
      Success<List<ComplianceAlert>>(value: final List<ComplianceAlert> rows) =>
        rows,
      _ => const <ComplianceAlert>[],
    };
    final int highOpen = alerts
        .where(
          (ComplianceAlert a) =>
              a.status == AlertStatus.open &&
              (a.severity == AlertSeverity.high ||
                  a.severity == AlertSeverity.critical),
        )
        .length;
    final int acknowledged = alerts
        .where((ComplianceAlert a) => a.status == AlertStatus.acknowledged)
        .length;
    final int cleared = alerts
        .where((ComplianceAlert a) => a.status == AlertStatus.resolved)
        .length;

    await open(tester, '/alerts');
    for (final int value in <int>[highOpen, acknowledged, cleared]) {
      expect(find.text('$value'), findsWidgets);
    }
    expect(find.text('High-severity open'), findsOneWidget);
    expect(find.text('Open investigations'), findsOneWidget);
    expect(find.text('Cleared'), findsOneWidget);
  });
}
