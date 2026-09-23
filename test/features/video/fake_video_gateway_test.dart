import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/video/data/fake_video_gateway.dart';
import 'package:legalhub/features/video/domain/consultation_session.dart';

void main() {
  group('FakeVideoGateway (spec D-15 demo-posture)', () {
    test('serves the fixed synthetic session list on every call', () async {
      final FakeVideoGateway gateway = FakeVideoGateway();

      final List<ConsultationSession> first =
          (await gateway.fetchSessions()).valueOrNull!;
      final List<ConsultationSession> second =
          (await gateway.fetchSessions()).valueOrNull!;

      // Same deterministic list both times (the booking-slots R3 rule).
      expect(first, FakeVideoGateway.syntheticSessions);
      expect(first.length, 4);
      expect(first.map((ConsultationSession s) => s.id).toList(), <String>[
        'video-1',
        'video-2',
        'video-3',
        'video-4',
      ]);
      // Second call is byte-identical — no drift, no state.
      expect(second, first);
    });

    test('rows are non-PII demo data only (the D-A4 honesty rule)', () {
      for (final ConsultationSession session
          in FakeVideoGateway.syntheticSessions) {
        expect(session.id, startsWith('video-'));
        expect(session.participantName, startsWith('Demo'));
        expect(session.topic, isNotEmpty);
      }
    });
  });
}
