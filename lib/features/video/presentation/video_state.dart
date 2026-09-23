import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/consultation_session.dart';

/// Immutable state of the video-consultation surface (spec D-15,
/// demo-posture).
///
/// - [sessions] — the session-list load lifecycle (the shared [ViewState]
///   vocabulary).
/// - [joinedSessionId] — the client-side "in the demo call" marker: non-null
///   while the synthetic call surface is up, null while browsing. **Pure UI
///   state** — it records nothing (C-3), requests no media (C-2), and never
///   travels out of the widget tree.
class VideoState extends Equatable {
  const VideoState({
    this.sessions = const ViewLoading<List<ConsultationSession>>(),
    this.joinedSessionId,
  });

  final ViewState<List<ConsultationSession>> sessions;

  /// The joined demo session's id, or null when browsing the list.
  final String? joinedSessionId;

  /// True while the synthetic call surface should be shown.
  bool get inCall => joinedSessionId != null;

  VideoState copyWith({
    ViewState<List<ConsultationSession>>? sessions,
    Object? joinedSessionId = _unset,
  }) {
    return VideoState(
      sessions: sessions ?? this.sessions,
      joinedSessionId: identical(joinedSessionId, _unset)
          ? this.joinedSessionId
          : joinedSessionId as String?,
    );
  }

  /// Sentinel distinguishing "not provided" from "explicitly null" so
  /// [joinedSessionId] can be cleared (leaving the call) through copyWith.
  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[sessions, joinedSessionId];
}
