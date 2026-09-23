import 'package:equatable/equatable.dart';

/// A synthetic video-consultation session (spec D-15, demo-posture).
///
/// Carries **non-PII data only**: a stable id, the demo participant display
/// name, a topic label, and the scheduled time. Nothing on the type implies
/// a real call, a real person, or a real schedule — rows come only from the
/// fake gateway's fixed synthetic list (the D-A4 attorney-profile honesty
/// rule, mirrored here per the video scope decision's C-1 seam posture).
class ConsultationSession extends Equatable {
  const ConsultationSession({
    required this.id,
    required this.participantName,
    required this.topic,
    required this.scheduledAt,
  });

  final String id;
  final String participantName;
  final String topic;
  final DateTime scheduledAt;

  @override
  List<Object?> get props => <Object?>[id, participantName, topic, scheduledAt];
}
