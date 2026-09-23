import '../../../core/errors/result.dart';
import '../domain/consultation_session.dart';
import '../domain/video_gateway.dart';

/// Development-only video-consultation implementation: a fixed synthetic
/// list of 4 deterministic, non-PII demo sessions (spec D-15, demo-posture;
/// `docs/video_scope_decision_2026-08-11.md`).
///
/// The fake IS the product posture for the demo (C-1): there is no
/// provider, no media path, and no persistence anywhere downstream. Rows
/// never read as a real calendar (the R1 fake-data honesty rule shared with
/// the booking slots and the attorney profiles).
class FakeVideoGateway implements VideoGateway {
  /// The fixed synthetic session list served by [fetchSessions].
  static final List<ConsultationSession> syntheticSessions =
      <ConsultationSession>[
        ConsultationSession(
          id: 'video-1',
          participantName: 'Demo attorney — A. Hassan',
          topic: 'Contract review — kickoff',
          scheduledAt: DateTime.utc(2026, 9, 24, 10, 0),
        ),
        ConsultationSession(
          id: 'video-2',
          participantName: 'Demo attorney — S. Ibrahim',
          topic: 'Incorporation walkthrough',
          scheduledAt: DateTime.utc(2026, 9, 25, 13, 30),
        ),
        ConsultationSession(
          id: 'video-3',
          participantName: 'Demo attorney — M. Farouk',
          topic: 'Employment dispute — follow-up',
          scheduledAt: DateTime.utc(2026, 9, 28, 9, 0),
        ),
        ConsultationSession(
          id: 'video-4',
          participantName: 'Demo attorney — L. Adel',
          topic: 'Family law consultation',
          scheduledAt: DateTime.utc(2026, 9, 29, 16, 0),
        ),
      ];

  @override
  Future<Result<List<ConsultationSession>>> fetchSessions() async {
    return Result<List<ConsultationSession>>.success(
      List<ConsultationSession>.unmodifiable(syntheticSessions),
    );
  }
}
