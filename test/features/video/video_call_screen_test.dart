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
}
