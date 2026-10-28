import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/features/video/presentation/video_call_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';

class _StubVideoGateway implements VideoGateway {
  @override
  Future<Result<List<VideoSession>>> fetchSessions() async {
    return const Result<List<VideoSession>>.success(<VideoSession>[]);
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    return const Result<String>.success('v-new');
  }

  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) async {
    return const Result<VideoToken>.success(
      VideoToken(
        url: 'wss://livekit.example',
        token: 'jwt-token',
        room: 'room_abcdef0123456789',
      ),
    );
  }

  @override
  Future<Result<void>> markLive(String id) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> end(String id) async {
    return const Result<void>.success(null);
  }
}

class _MockRoom extends Mock implements Room {}

class _MockLocalParticipant extends Mock implements LocalParticipant {}

_MockRoom _newRoom() {
  final _MockRoom room = _MockRoom();
  when(() => room.localParticipant).thenReturn(null);
  when(() => room.remoteParticipants).thenReturn(
    UnmodifiableMapView<String, RemoteParticipant>(
      <String, RemoteParticipant>{},
    ),
  );
  when(() => room.disconnect()).thenAnswer((_) async {});
  when(() => room.dispose()).thenAnswer((_) async => true);
  return room;
}

Future<void> _noopTeardown(Room room) async {}

final VideoSession _session = VideoSession(
  id: 'v1',
  organizationId: 'org-1',
  roomName: 'room_abcdef0123456789',
  status: VideoSessionStatus.scheduled,
  scheduledAt: DateTime.utc(2026, 10, 25, 10),
);

const VideoToken _token = VideoToken(
  url: 'wss://livekit.example',
  token: 'jwt-token',
  room: 'room_abcdef0123456789',
);

void main() {
  group('teardownVideoRoom', () {
    test('disconnects then disposes the room', () async {
      final _MockRoom room = _MockRoom();
      final List<String> calls = <String>[];
      when(() => room.disconnect()).thenAnswer((_) async {
        calls.add('disconnect');
      });
      when(() => room.dispose()).thenAnswer((_) async {
        calls.add('dispose');
        return true;
      });

      await teardownVideoRoom(room);

      expect(calls, <String>['disconnect', 'dispose']);
    });

    test('a failed disconnect still disposes the room', () async {
      final _MockRoom room = _MockRoom();
      when(() => room.disconnect()).thenThrow(StateError('already gone'));
      when(() => room.dispose()).thenAnswer((_) async => true);

      await teardownVideoRoom(room);

      verify(() => room.dispose()).called(1);
    });
  });

  Future<void> pumpCall(
    WidgetTester tester, {
    required VideoRoomConnector connector,
    VideoRoomTeardown? teardown,
    Room Function()? roomFactory,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoCallScreen(
          session: _session,
          token: _token,
          gateway: _StubVideoGateway(),
          connector: connector,
          teardown: teardown ?? _noopTeardown,
          roomFactory: roomFactory ?? _newRoom,
        ),
      ),
    );
    await tester.pump();
  }

  group('VideoCallScreen pre-connect state (plan Task 8)', () {
    testWidgets('shows the connecting state and a leave escape hatch', (
      tester,
    ) async {
      final Completer<void> never = Completer<void>();
      await pumpCall(tester, connector: (_, _, _) => never.future);

      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('Leave call'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a connector failure renders the retryable failure state and '
        'tears the created room down', (tester) async {
      final _MockRoom room = _newRoom();
      final List<Room> tornDown = <Room>[];
      await pumpCall(
        tester,
        roomFactory: () => room,
        teardown: (Room value) async => tornDown.add(value),
        connector: (_, _, _) async => throw StateError('no media'),
      );
      await tester.pump();

      expect(find.text('Unable to connect to the call.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Leave call'), findsOneWidget);
      expect(tornDown, <Room>[room]);
    });

    testWidgets('unmount tears the live room down', (tester) async {
      final _MockRoom room = _newRoom();
      final List<Room> tornDown = <Room>[];
      await pumpCall(
        tester,
        roomFactory: () => room,
        teardown: (Room value) async => tornDown.add(value),
        connector: (_, _, _) async {},
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tornDown, <Room>[room]);
    });
  });

  group('videoRoomOptions (plan Task 8)', () {
    test('the room uses a 360p/15fps adaptive profile', () {
      final RoomOptions options = videoRoomOptions();

      expect(options.adaptiveStream, isTrue);
      expect(options.dynacast, isTrue);
      expect(
        options.defaultCameraCaptureOptions.params,
        VideoParametersPresets.h360_169,
      );
      expect(options.defaultCameraCaptureOptions.maxFrameRate, 15);
      expect(
        options.defaultVideoPublishOptions.videoEncoding?.maxBitrate,
        450000,
      );
      expect(
        options.defaultVideoPublishOptions.videoEncoding?.maxFramerate,
        15,
      );
    });
  });

  group('VideoCallScreen media lifecycle (plan Task 8)', () {
    /// A local participant mock with the media surface the screen touches.
    _MockLocalParticipant stubLocal(Room room) {
      final _MockLocalParticipant local = _MockLocalParticipant();
      when(() => local.isCameraEnabled()).thenReturn(true);
      when(() => local.isMicrophoneEnabled()).thenReturn(true);
      when(() => local.setCameraEnabled(any())).thenAnswer((_) async => null);
      when(
        () => local.setMicrophoneEnabled(any()),
      ).thenAnswer((_) async => null);
      when(
        () => local.videoTrackPublications,
      ).thenReturn(const <LocalTrackPublication<LocalVideoTrack>>[]);
      when(() => room.localParticipant).thenReturn(local);
      return local;
    }

    testWidgets('backgrounding disables camera and mic, resuming re-enables '
        'them', (tester) async {
      final _MockRoom room = _newRoom();
      final _MockLocalParticipant local = stubLocal(room);

      await pumpCall(
        tester,
        roomFactory: () => room,
        connector: (_, _, _) async {},
      );
      await tester.pumpAndSettle();

      // Initial enable from _enableMedia.
      verify(() => local.setCameraEnabled(true)).called(1);
      verify(() => local.setMicrophoneEnabled(true)).called(1);

      // mocktail's verify consumes the matched calls, so each phase is
      // counted on its own interactions.
      clearInteractions(local);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      verify(() => local.setCameraEnabled(false)).called(1);
      verify(() => local.setMicrophoneEnabled(false)).called(1);
      verifyNever(() => local.setCameraEnabled(true));
      verifyNever(() => local.setMicrophoneEnabled(true));

      clearInteractions(local);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verify(() => local.setCameraEnabled(true)).called(1);
      verify(() => local.setMicrophoneEnabled(true)).called(1);
      verifyNever(() => local.setCameraEnabled(false));
      verifyNever(() => local.setMicrophoneEnabled(false));
    });

    testWidgets('resuming restores the user intent, not a forced enable', (
      tester,
    ) async {
      final _MockRoom room = _newRoom();
      final _MockLocalParticipant local = stubLocal(room);

      await pumpCall(
        tester,
        roomFactory: () => room,
        connector: (_, _, _) async {},
      );
      await tester.pumpAndSettle();

      // The user mutes the microphone from the in-call controls.
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      verify(() => local.setMicrophoneEnabled(false)).called(1);
      clearInteractions(local);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      verify(() => local.setMicrophoneEnabled(false)).called(1);
      clearInteractions(local);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // Still muted: the pause must not overwrite the user's intent.
      verify(() => local.setMicrophoneEnabled(false)).called(1);
      verifyNever(() => local.setMicrophoneEnabled(true));
      verify(() => local.setCameraEnabled(true)).called(1);
    });

    testWidgets('a lifecycle pause before the room connects is ignored', (
      tester,
    ) async {
      final Completer<void> never = Completer<void>();
      await pumpCall(tester, connector: (_, _, _) => never.future);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Connecting…'), findsOneWidget);
    });

    testWidgets('a failing pause is swallowed and leaves the call connected', (
      tester,
    ) async {
      final _MockRoom room = _newRoom();
      final _MockLocalParticipant local = stubLocal(room);
      when(
        () => local.setMicrophoneEnabled(false),
      ).thenThrow(StateError('torn down'));

      await pumpCall(
        tester,
        roomFactory: () => room,
        connector: (_, _, _) async {},
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });
  });
}
