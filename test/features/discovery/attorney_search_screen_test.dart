import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/discovery/data/fake_attorney_gateway.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/presentation/attorney_search_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpSearch(WidgetTester tester) async {
    // AttorneySearchScreen resolves AttorneyGateway from the locator (the dev
    // fake in env-less runs).
    configureDependencies();
    // A tall surface so the full synthetic list builds inside the ListView
    // (children below the fold are not built, which would hide later rows).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AttorneySearchScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('attorney search surface (Phase 6 slice 6.1)', () {
    testWidgets('lists the synthetic attorneys from the fake gateway (AC-1)', (
      tester,
    ) async {
      await pumpSearch(tester);

      expect(find.text('Find an Attorney'), findsOneWidget);
      for (final Attorney attorney in FakeAttorneyGateway.syntheticAttorneys) {
        expect(find.text(attorney.name), findsOneWidget);
      }
      // Every row pairs the name with its practice area + locale.
      expect(find.text('Corporate · EN / AR'), findsWidgets);
    });

    testWidgets('filters by name as the user types (AC-2)', (tester) async {
      await pumpSearch(tester);

      await tester.enterText(find.byType(TextFormField), 'Layla');
      await tester.pumpAndSettle();

      expect(find.text('Layla Mansour'), findsOneWidget);
      expect(find.text('Omar Farouk'), findsNothing);
    });

    testWidgets('filters by practice area via the chip (AC-2)', (tester) async {
      await pumpSearch(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Civil'));
      await tester.pumpAndSettle();

      expect(find.text('Omar Farouk'), findsOneWidget);
      expect(find.text('Layla Mansour'), findsNothing);
      expect(find.text('Sara Khalil'), findsNothing);
    });

    testWidgets(
      'an empty result set renders the localized empty state (AC-2)',
      (tester) async {
        await pumpSearch(tester);

        await tester.enterText(find.byType(TextFormField), 'zzz-nobody');
        await tester.pumpAndSettle();

        expect(find.text('No attorneys match your search.'), findsOneWidget);
        expect(find.text('Layla Mansour'), findsNothing);
      },
    );

    testWidgets('carries the local-only demo note (R1)', (tester) async {
      await pumpSearch(tester);

      // The synthetic list must never read as a real directory.
      expect(find.textContaining('synthetic profiles only'), findsOneWidget);
    });
  });
}
