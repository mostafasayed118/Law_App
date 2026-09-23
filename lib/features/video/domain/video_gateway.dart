import '../../../core/errors/result.dart';
import 'consultation_session.dart';

/// Video-consultation integration boundary (spec D-15, demo-posture).
///
/// **Synthetic demo surface only**, per the ratified video scope decision
/// (`docs/video_scope_decision_2026-08-11.md`):
///
/// - **C-1** — the seam is synthetic; the fake implementation IS the product
///   posture for the demo, not a stopgap.
/// - **C-2** — no real media anywhere downstream of this interface: no
///   camera/mic permission requests, no media streams, no WebRTC.
/// - **C-3** — zero writes: joining or leaving a demo call records nothing,
///   writes no call row, and adds no audit entry (audit is for real server
///   outcomes only).
/// - **B-2** — a real product records a named provider at slice-planning
///   time (the D-11 billing pattern) with hosted infrastructure; nothing
///   here anticipates one.
abstract interface class VideoGateway {
  Future<Result<List<ConsultationSession>>> fetchSessions();
}
