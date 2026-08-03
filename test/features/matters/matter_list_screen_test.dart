import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
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
  });
}

/// Gateway stub that yields an empty matter list (empty-state widget pin).
class _EmptyMatterGateway implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    return Result<List<Matter>>.success(const <Matter>[]);
  }
}
