import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/video/presentation/video_consultation_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpVideo(
    WidgetTester tester, {
    bool canCreate = false,
    bool canEndAny = false,
    String? currentUserId,
  }) async {
    configureDependencies();
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoConsultationScreen(
          canCreate: canCreate,
          canEndAny: canEndAny,
          currentUserId: currentUserId,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('video consultation screen (design §6)', () {
    testWidgets('lists sessions with statuses and the permitted actions', (
      tester,
    ) async {
      await pumpVideo(tester, canEndAny: true, currentUserId: 'demo-user');

      expect(find.text('Video consultations'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      // Scheduled + live rows are joinable; ended/cancelled rows are not.
      expect(find.text('Join call'), findsNWidgets(2));
      // Creator (scheduled) + partner (live) can end; the ended row cannot.
      expect(find.text('End'), findsNWidgets(2));
      expect(
        find.text(
          'Demo mode — sample sessions only. Video calls require a configured deployment.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a client sees join but no end action', (tester) async {
      await pumpVideo(tester, currentUserId: 'other-user');

      expect(find.text('Join call'), findsNWidgets(2));
      expect(find.text('End'), findsNothing);
    });

    testWidgets('joining without provider secrets shows the honest '
        'unavailable state and opens no call', (tester) async {
      await pumpVideo(tester);

      await tester.tap(find.text('Join call').first);
      await tester.pumpAndSettle();

      expect(find.text('Call unavailable'), findsOneWidget);
      expect(
        find.text(
          'Video calls are not configured for this deployment. No call was started.',
        ),
        findsOneWidget,
      );
      expect(find.text('Leave call'), findsNothing);
    });

    testWidgets('the create sheet refuses to submit without an organization', (
      tester,
    ) async {
      await pumpVideo(tester, canCreate: true);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule a video consultation'), findsOneWidget);
      expect(
        find.text('Select an organization before scheduling a session.'),
        findsOneWidget,
      );
      final FilledButton submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Schedule session'),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('the create sheet requires a date and time', (tester) async {
      await pumpVideo(tester, canCreate: true);
      serviceLocator<ActiveOrgStore>().select('org-demo');

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Schedule session'));
      await tester.tap(find.text('Schedule session'));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a date and time for the session.'),
        findsOneWidget,
      );
    });
  });
}
