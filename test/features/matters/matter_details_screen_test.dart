import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_details_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDetails(WidgetTester tester, String matterId) async {
    // MatterDetailsScreen resolves MatterGateway from the locator (the dev
    // fake in env-less runs).
    configureDependencies();
    // A tall surface so the full details projection builds inside the
    // ListView (children below the fold are not built).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // Pin the locale so l10n.localeName == 'en' and the date assertion
        // below is exact rather than coincidental (same harness choice as
        // router_test).
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MatterDetailsScreen(matterId: matterId),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('matter details (Phase 7 slice 7.2)', () {
    testWidgets(
      'renders the read-only projection — status, practice area, attorney, '
      'created date (AC-3)',
      (tester) async {
        await pumpDetails(tester, 'matter-1');

        final Matter matter = FakeMatterGateway.syntheticMatters.firstWhere(
          (Matter m) => m.id == 'matter-1',
        );

        expect(find.text('Matter details'), findsOneWidget);
        expect(find.text(matter.title), findsOneWidget);
        expect(find.text('Active'), findsOneWidget); // status chip
        expect(find.text('Corporate'), findsOneWidget); // practice area
        expect(find.text('Layla Mansour'), findsOneWidget); // attorney
        // Created date renders locale-aware (same shape as the profile
        // surface's date rows).
        final DateFormat createdFormat = DateFormat.yMMMd('en');
        expect(
          find.text(createdFormat.format(matter.createdAt)),
          findsOneWidget,
        );
      },
    );

    testWidgets('read-only line pin: no action buttons on the surface (AC-3)', (
      tester,
    ) async {
      await pumpDetails(tester, 'matter-1');

      // D-M1: the details projection is display-only — no create/edit/close/
      // upload affordances anywhere. The pin targets the action-button types
      // only: an AppBar back button (an IconButton, present only when the
      // route is push-navigated) is navigation, not a matter action, so it
      // must never trip this line.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('an unknown id renders the localized not-found state', (
      tester,
    ) async {
      await pumpDetails(tester, 'no-such-id');

      expect(find.text('Matter not found.'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('carries the local-only demo note (R1)', (tester) async {
      await pumpDetails(tester, 'matter-1');

      // The synthetic matter must never read as a real case.
      expect(find.textContaining('synthetic matters only'), findsOneWidget);
    });

    testWidgets('a load failure renders the error state and retry reloads', (
      tester,
    ) async {
      // Stub gateway: first call fails, retry succeeds — registered before
      // configureDependencies so the fake registration is skipped.
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<MatterGateway>(
        _RetryMatterGateway.new,
      );

      await pumpDetails(tester, 'matter-1');

      expect(find.text('Unable to load matters.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // The retry resolved into the real details projection.
      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.text('Unable to load matters.'), findsNothing);
    });
  });
}

/// Gateway stub that fails once then succeeds (retry round-trip pin).
class _RetryMatterGateway implements MatterGateway {
  int _calls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    _calls++;
    if (_calls == 1) {
      return Result<List<Matter>>.failure(
        const AppError(code: 'matters_failed', userMessage: 'failed'),
      );
    }
    return Result<List<Matter>>.success(FakeMatterGateway.syntheticMatters);
  }
}
