import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/video/data/fake_video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';

void main() {
  group('FakeVideoGateway (env-less demo seam)', () {
    test('serves the fixed schedule and covers every status', () async {
      final FakeVideoGateway gateway = FakeVideoGateway();

      final List<VideoSession> first =
          (await gateway.fetchSessions()).valueOrNull!;
      final List<VideoSession> second =
          (await gateway.fetchSessions()).valueOrNull!;

      expect(first, FakeVideoGateway.syntheticSessions);
      expect(first.length, 4);
      expect(
        first.map((VideoSession s) => s.status).toSet(),
        VideoSessionStatus.values.toSet(),
      );
      expect(second, first);
      expect(
        first.map((VideoSession s) => s.id),
        everyElement(startsWith('video-')),
      );
    });

    test(
      'never fabricates a call — the token step is provider-missing',
      () async {
        final FakeVideoGateway gateway = FakeVideoGateway();

        final VideoToken? token = (await gateway.fetchToken(
          'video-1',
        )).valueOrNull;
        final String code = (await gateway.fetchToken(
          'video-1',
        )).errorOrNull!.code;

        expect(token, isNull);
        expect(code, 'provider_not_configured');
      },
    );

    test('createSession appends a scheduled row', () async {
      final FakeVideoGateway gateway = FakeVideoGateway();

      final String? id = (await gateway.createSession(
        matterId: 'matter-1',
        scheduledAt: DateTime.utc(2026, 11, 1, 9),
      )).valueOrNull;

      expect(id, isNotNull);
      final List<VideoSession> sessions =
          (await gateway.fetchSessions()).valueOrNull!;
      final VideoSession created = sessions.firstWhere(
        (VideoSession session) => session.id == id,
      );
      expect(created.status, VideoSessionStatus.scheduled);
      expect(created.matterId, 'matter-1');
      expect(created.createdBy, 'demo-user');
    });

    test('markLive and end transition an existing row', () async {
      final FakeVideoGateway gateway = FakeVideoGateway();

      expect((await gateway.markLive('video-1')).isSuccess, isTrue);
      expect((await gateway.end('video-1')).isSuccess, isTrue);

      final VideoSession updated = (await gateway.fetchSessions()).valueOrNull!
          .firstWhere((VideoSession session) => session.id == 'video-1');
      expect(updated.status, VideoSessionStatus.ended);
      expect(updated.isJoinable, isFalse);
    });

    test('unknown ids fail typed instead of fabricating a row', () async {
      final FakeVideoGateway gateway = FakeVideoGateway();

      expect(
        (await gateway.markLive('missing')).errorOrNull!.code,
        'video_session_not_found',
      );
      expect(
        (await gateway.end('missing')).errorOrNull!.code,
        'video_session_not_found',
      );
    });
  });
}
