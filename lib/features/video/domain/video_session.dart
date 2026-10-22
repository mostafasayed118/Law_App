import 'package:equatable/equatable.dart';

/// Lifecycle of a persisted video consultation (`video_sessions.status`).
enum VideoSessionStatus { scheduled, live, ended, cancelled }

/// A persisted video consultation (design §6).
///
/// Rows come from `list_video_sessions` under the caller's RLS scope; the
/// room name is provider routing metadata and is only ever sent back to the
/// `video-token` function. [createdBy] is carried so presentation can offer
/// the "end" action to the creator (the `end_video_session` RPC re-asserts
/// the creator-or-partner gate server-side).
class VideoSession extends Equatable {
  const VideoSession({
    required this.id,
    required this.organizationId,
    required this.roomName,
    required this.status,
    this.matterId,
    this.bookingId,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.createdBy,
  });

  final String id;
  final String organizationId;
  final String? matterId;
  final String? bookingId;
  final String roomName;
  final VideoSessionStatus status;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? createdBy;

  /// True while the provider can still admit participants.
  bool get isJoinable =>
      status == VideoSessionStatus.scheduled ||
      status == VideoSessionStatus.live;

  /// Copy with a new lifecycle snapshot (the fake gateway's in-memory rows).
  VideoSession copyWith({
    VideoSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return VideoSession(
      id: id,
      organizationId: organizationId,
      matterId: matterId,
      bookingId: bookingId,
      roomName: roomName,
      status: status ?? this.status,
      scheduledAt: scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdBy: createdBy,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    organizationId,
    matterId,
    bookingId,
    roomName,
    status,
    scheduledAt,
    startedAt,
    endedAt,
    createdBy,
  ];
}
