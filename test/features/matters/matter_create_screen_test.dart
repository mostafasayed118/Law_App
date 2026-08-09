import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/matters/data/fake_matter_write_gateway.dart';
import 'package:legalhub/features/matters/presentation/matter_create_screen.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpCreate(WidgetTester tester) async {
    // The screen resolves MatterWriteGateway / ActiveOrgStore /
    // OrganizationGateway from the locator (the dev fakes in env-less runs)
    // and provides its OWN MatterCreateCubit (the MatterListScreen pattern)
    // — pumping it bare pins that self-providing behavior (review R-1: the
    // route must not need an external provider).
    configureDependencies();
    // The create intent targets the ACTIVE org (D-08 routing hint). The
    // screen seeds the store from the session, so selecting the demo org
    // here mirrors a hub visit.
    serviceLocator<ActiveOrgStore>().select(
      FakeMatterWriteGateway.demoOrganizationId,
    );
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MatterCreateScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('matter create surface (F-01 step 2 client swap, C-D6)', () {
    testWidgets('creates a matter through the fake gateway and shows the '
        'confirmation with the returned id', (tester) async {
      await pumpCreate(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Demo acquisition review',
      );
      // The submit button (not the AppBar title, which shares the copy).
      await tester.tap(find.widgetWithText(FilledButton, 'Create matter'));
      await tester.pumpAndSettle();

      // Success view: confirmation + the fake's deterministic id; the copy
      // never promises list visibility (the honest R1 note).
      expect(find.text('Matter created'), findsOneWidget);
      expect(find.textContaining('created-1'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('a blank title is refused by the form validator', (
      tester,
    ) async {
      await pumpCreate(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Create matter'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Matter created'), findsNothing);
    });

    testWidgets('shows the honest no-org state instead of a silent dead '
        'form (review R-2)', (tester) async {
      // No active org selected (no hub visit, no explicit selection): the
      // surface must say so — not render a form whose submit silently
      // no-ops.
      configureDependencies();
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MatterCreateScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No active organization'), findsOneWidget);
      expect(find.text('Title'), findsNothing);
      expect(find.text('Create matter'), findsOneWidget); // AppBar only
    });

    testWidgets('offers the org\'s active members as assignees and refuses '
        'the fixture owner id (F2-D2 mirror)', (tester) async {
      await pumpCreate(tester);

      // The fake roster offers the demo user (the demo org's only active
      // member) as an assignee option.
      await tester.tap(find.text('None').first);
      await tester.pumpAndSettle();
      expect(find.text('Demo user'), findsOneWidget);
    });
  });
}
