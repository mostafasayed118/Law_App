import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/video/data/fake_video_gateway.dart';
import 'package:legalhub/features/video/domain/consultation_session.dart';
import 'package:legalhub/features/video/presentation/video_consultation_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpVideo(WidgetTester tester) async {
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const VideoConsultationScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('video consultation screen (spec D-15 demo-posture)', () {
    testWidgets('lists the synthetic sessions from the fake gateway', (
      tester,
    ) async {
      await pumpVideo(tester);

      expect(find.text('Video consultation'), findsOneWidget);
      for (final ConsultationSession session
          in FakeVideoGateway.syntheticSessions) {
        expect(find.text(session.participantName), findsOneWidget);
        expect(find.textContaining(session.topic), findsOneWidget);
      }
      expect(find.text('Join demo call'), findsNWidgets(4));
      // The demo posture is stated on the list mode too.
      expect(
        find.textContaining('Demo mode — synthetic sessions only'),
        findsOneWidget,
      );
    });

    testWidgets('join opens the synthetic call surface for that session', (
      tester,
    ) async {
      await pumpVideo(tester);

      await tester.tap(find.text('Join demo call').first);
      // Explicit pumps, not pumpAndSettle: the call surface's 1-second
      // elapsed ticker schedules a frame every fake-second, so a settle
      // would never return.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The call surface names the joined participant and never the others.
      expect(
        find.text('Demo call with Demo attorney — A. Hassan'),
        findsOneWidget,
      );
      expect(find.text('Demo attorney — S. Ibrahim'), findsNothing);
      // Live badge, participant tiles, and the posture note are present.
      expect(find.text('Live demo'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(
        find.text('No real audio or video. Nothing is recorded or sent.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });

    testWidgets('leave returns to the session list', (tester) async {
      await pumpVideo(tester);

      await tester.tap(find.text('Join demo call').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Leave call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Join demo call'), findsNWidgets(4));
      expect(find.text('Live demo'), findsNothing);
    });

    testWidgets('mic/camera toggles flip local state without any permission '
        'request (C-2)', (tester) async {
      await pumpVideo(tester);

      await tester.tap(find.text('Join demo call').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      expect(find.byIcon(Icons.mic_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.videocam));
      await tester.pump();
      expect(find.byIcon(Icons.videocam_off), findsOneWidget);
    });

    testWidgets('the elapsed readout is present in the call surface', (
      tester,
    ) async {
      await pumpVideo(tester);

      await tester.tap(find.text('Join demo call').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Elapsed'), findsOneWidget);
      // Advancing fake time ticks the readout (the periodic timer is
      // driven by the test's fake async zone).
      await tester.pump(const Duration(seconds: 65));
      expect(find.textContaining('Elapsed 01:'), findsOneWidget);
    });
  });
}
