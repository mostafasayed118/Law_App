import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_write_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_create_screen.dart';
import 'package:legalhub/features/matters/presentation/matter_list_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpList(WidgetTester tester) async {
    // MatterListScreen resolves MatterGateway from the locator (the dev fake
    // in env-less runs).
    configureDependencies();
    // A tall surface so the full synthetic list builds inside the ListView.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MatterListScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('matter list surface (Phase 7 slice 7.1)', () {
    testWidgets('lists the synthetic matters from the fake gateway (AC-1)', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.text('Matters'), findsOneWidget);
      for (final Matter matter in FakeMatterGateway.syntheticMatters) {
        expect(find.text(matter.title), findsOneWidget);
      }
      // Every row pairs the title with its practice area + assigned attorney.
      expect(find.text('Corporate · Layla Mansour'), findsOneWidget);
      // Rows carry the details affordance (slice 7.2 navigation hint); the
      // tap itself is exercised in router_test under the real GoRouter.
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets('filters by lifecycle status via the chip (AC-2)', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Active'));
      await tester.pumpAndSettle();

      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.text('Family status consultation'), findsOneWidget);
      expect(find.text('Commercial lease consultation'), findsNothing);
      expect(find.text('Procedural review matter'), findsNothing);
    });

    testWidgets(
      'an empty result set renders the localized empty state (AC-2)',
      (tester) async {
        // Stub gateway returning an empty list, registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<MatterGateway>(
          _EmptyMatterGateway.new,
        );

        await pumpList(tester);

        expect(find.text('No matters match the filter.'), findsOneWidget);
        expect(find.text('Demo acquisition review'), findsNothing);
      },
    );

    testWidgets('carries the local-only demo note (R1)', (tester) async {
      await pumpList(tester);

      // The synthetic list must never read as real cases.
      expect(find.textContaining('synthetic matters only'), findsOneWidget);
    });

    testWidgets('hides the create entry by default (UX-only partner gate)', (
      tester,
    ) async {
      await pumpList(tester);

      // F-01 step 2 client swap: the FAB is offered only when the router
      // resolves the active role to partner; the default (tests, and any
      // caller the router does not gate) is hidden.
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('shows the create entry when the router gates it to partner', (
      tester,
    ) async {
      configureDependencies();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MatterListScreen(canCreateMatter: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New matter'), findsOneWidget);
    });

    testWidgets('re-reads the list when the create screen closes (W4)', (
      tester,
    ) async {
      // A read gateway that grows a row on every fetch AFTER the first: the
      // new row shows up in the list only if the list fetched AGAIN once the
      // create screen closed (the create screen runs its OWN cubit, so it
      // never touches this list on its own).
      final _GrowingMatterGateway gateway = _GrowingMatterGateway();
      await resetServiceLocator();
      // Registered BEFORE configureDependencies so the fake registration is
      // skipped (the empty-gateway stub above uses the same seam).
      serviceLocator.registerLazySingleton<MatterGateway>(() => gateway);
      configureDependencies();
      // The create intent targets the ACTIVE org (the demo org of the fake
      // roster seam), selected here the way a hub visit would.
      serviceLocator<ActiveOrgStore>().select(
        FakeMatterWriteGateway.demoOrganizationId,
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.matters,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.matters,
            builder: (BuildContext context, GoRouterState state) =>
                const MatterListScreen(canCreateMatter: true),
          ),
          GoRoute(
            path: AppRoutes.matterCreate,
            builder: (BuildContext context, GoRouterState state) =>
                const MatterCreateScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(gateway.fetchCount, 1);

      // Create a matter from the FAB (the partner-gated entry).
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Fresh matter',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create matter'));
      await tester.pumpAndSettle();
      expect(find.text('Matter created'), findsOneWidget);

      // Done pops back to the list — which must now carry the new row.
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text('Fresh matter'), findsOneWidget);
      expect(gateway.fetchCount, 2);
    });
  });
}

/// Gateway stub that yields an empty matter list (empty-state widget pin).
class _EmptyMatterGateway implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    return Result<List<Matter>>.success(const <Matter>[]);
  }

  @override
  Future<Result<List<Matter>>> searchMatters(String query, {int limit = 30}) =>
      fetchMatters();
}

/// Gateway stub whose list grows on every fetch after the first (W4 refresh
/// pin): the extra row stands for the matter created on the create screen.
class _GrowingMatterGateway implements MatterGateway {
  /// How many times the list has been read.
  int fetchCount = 0;

  static final Matter _first = Matter(
    id: 'matter-1',
    title: 'Demo acquisition review',
    practiceArea: PracticeArea.corporate,
    status: MatterStatus.active,
    assignedAttorneyName: 'Layla Mansour',
    createdAt: DateTime.utc(2026, 7, 12),
  );

  static final Matter _created = Matter(
    id: 'created-1',
    title: 'Fresh matter',
    practiceArea: PracticeArea.corporate,
    status: MatterStatus.open,
    assignedAttorneyName: 'Layla Mansour',
    createdAt: DateTime.utc(2026, 10, 21),
  );

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    fetchCount++;
    return Result<List<Matter>>.success(<Matter>[
      _first,
      if (fetchCount > 1) _created,
    ]);
  }

  @override
  Future<Result<List<Matter>>> searchMatters(String query, {int limit = 30}) =>
      fetchMatters();
}
