import 'package:equatable/equatable.dart';

import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/video/domain/video_session.dart';

/// Immutable state of the video-consultation surface (design §6).
class VideoState extends Equatable {
  const VideoState({this.sessions = const ViewLoading<List<VideoSession>>()});

  /// The session-list load lifecycle (the shared [ViewState] vocabulary).
  final ViewState<List<VideoSession>> sessions;

  VideoState copyWith({ViewState<List<VideoSession>>? sessions}) {
    return VideoState(sessions: sessions ?? this.sessions);
  }

  @override
  List<Object?> get props => <Object?>[sessions];
}
