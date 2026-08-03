import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/discovery/presentation/attorney_profile_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpProfile(WidgetTester tester, String attorneyId) async {
    // AttorneyProfileScreen resolves AttorneyGateway from the locator (the
    // dev fake in env-less runs).
    configureDependencies();
    // A tall surface so the profile content and the booking button build
    // inside the ListView (children below the fold are not built).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AttorneyProfileScreen(attorneyId: attorneyId),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('attorney profile (Phase 6 slice 6.2)', () {
    testWidgets(
      'renders name, practice area, locale, and bio — no private PII (AC-3)',
      (tester) async {
        await pumpProfile(tester, 'atty-1');

        expect(find.text('Attorney profile'), findsOneWidget);
        expect(find.text('Layla Mansour'), findsOneWidget);
        // The practice area + locale render as one summary line.
        expect(find.text('Corporate · EN / AR'), findsOneWidget);
        expect(
          find.text('Corporate transactions and governance counsel.'),
          findsOneWidget,
        );
        expect(find.text('Book with this attorney'), findsOneWidget);

        // D-A4: no contact/credential fields anywhere on the surface.
        expect(find.textContaining('Email'), findsNothing);
        expect(find.textContaining('Phone'), findsNothing);
        expect(find.textContaining('@'), findsNothing);
      },
    );

    testWidgets('carries the local-only demo note (R1)', (tester) async {
      await pumpProfile(tester, 'atty-1');

      // The synthetic profile must never read as a real directory entry.
      expect(find.textContaining('synthetic profiles only'), findsOneWidget);
    });

    testWidgets('an unknown id renders the localized not-found state', (
      tester,
    ) async {
      await pumpProfile(tester, 'no-such-id');

      expect(find.text('Attorney not found.'), findsOneWidget);
      expect(find.text('Book with this attorney'), findsNothing);
    });
  });
}
