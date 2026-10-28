import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/features/video/presentation/video_consultation_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<_PendingTokenVideoGateway> pumpVideo(WidgetTester tester) async {
    configureDependencies();
    final _PendingTokenVideoGateway gateway = _PendingTokenVideoGateway();
    // The fake is registered lazily; replace it before the screen resolves it
    // so the token call stays in flight across both taps.
    await serviceLocator.unregister<VideoGateway>();
    serviceLocator.registerSingleton<VideoGateway>(gateway);

    tester.view.physicalSize = const Size(1000, 1800);
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
    return gateway;
  }

  testWidgets('a second Join while the first is in flight keeps one token '
      'call and one dialog (audit 2026-10-27, F16)', (
    WidgetTester tester,
  ) async {
    final _PendingTokenVideoGateway gateway = await pumpVideo(tester);
    final FilledButton join = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join call'),
    );
    expect(join.onPressed, isNotNull);

    // Two activations of the same Join action before the token settles. The
    // first pushes the progress route and suspends; the second must be a
    // no-op instead of stacking a dialog and a second call screen.
    join.onPressed!();
    join.onPressed!();
    await tester.pump();

    expect(gateway.tokenCalls, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gateway.token.complete(
      const Result<VideoToken>.failure(
        AppError(
          code: 'provider_not_configured',
          userMessage:
              'Video calls are not configured for this deployment. '
              'No call was started.',
          kind: AppErrorKind.unavailable,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one join settled: the progress dialog is gone (replaced by the
    // single typed error), never a second stacked dialog.
    expect(gateway.tokenCalls, 1);
    expect(find.text('Connecting…'), findsNothing);
    expect(find.text('Call unavailable'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Leave call'), findsNothing);
  });
}

/// Serves one scheduled session and holds the room-token call open until the
/// test completes it, so a second Join can be attempted mid-flight.
class _PendingTokenVideoGateway implements VideoGateway {
  final Completer<Result<VideoToken>> token = Completer<Result<VideoToken>>();
  int tokenCalls = 0;

  @override
  Future<Result<List<VideoSession>>> fetchSessions() async =>
      Result<List<VideoSession>>.success(<VideoSession>[
        VideoSession(
          id: 'video-1',
          organizationId: 'org-demo',
          roomName: 'room_demo000000000001',
          status: VideoSessionStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 10, 25, 10, 0),
          createdBy: 'demo-user',
        ),
      ]);

  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) {
    tokenCalls += 1;
    return token.future;
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async => const Result<String>.success('video-new');

  @override
  Future<Result<void>> markLive(String id) async =>
      const Result<void>.success(null);

  @override
  Future<Result<void>> end(String id) async => const Result<void>.success(null);
}
