import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/consultation_session.dart';
import '../domain/video_gateway.dart';
import 'video_state.dart';

/// Owns the video-consultation surface (spec D-15, demo-posture).
///
/// [load] fetches the deterministic synthetic list on screen open (the
/// approvals/vault pattern). [join]/[leave] toggle the client-side demo-call
/// marker — **no gateway call, no write, no media request anywhere** (C-2/
/// C-3): joining a demo call is a pure state transition inside this cubit.
class VideoCubit extends Cubit<VideoState> {
  VideoCubit(this._gateway) : super(const VideoState());

  final VideoGateway _gateway;

  bool _loading = false;

  /// Loads the synthetic session list. The first open never re-emits a
  /// redundant loading frame (the initial state is already loading);
  /// duplicate calls while a load is in flight are ignored (the
  /// [DiscoveryCubit.load] discipline). An empty list maps to [ViewEmpty];
  /// a failure to [ViewError] with the joined marker untouched.
  Future<void> load() async {
    if (isClosed || _loading) {
      return;
    }
    _loading = true;
    if (state.sessions is! ViewLoading<List<ConsultationSession>>) {
      emit(
        state.copyWith(
          sessions: const ViewLoading<List<ConsultationSession>>(),
        ),
      );
    }
    final Result<List<ConsultationSession>> result = await _gateway
        .fetchSessions();
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<ConsultationSession>>(
        value: final List<ConsultationSession> sessions,
      ):
        emit(
          state.copyWith(
            sessions: sessions.isEmpty
                ? const ViewEmpty<List<ConsultationSession>>()
                : ViewSuccess<List<ConsultationSession>>(sessions),
          ),
        );
      case Failure<List<ConsultationSession>>(error: final AppError error):
        emit(
          state.copyWith(
            sessions: viewStateForFailure<List<ConsultationSession>>(error),
          ),
        );
    }
  }

  /// Enters the synthetic demo call for [sessionId]. No-op when the session
  /// is unknown (a stale row can never open a call surface) or when a call
  /// is already joined — one call at a time, like the real thing.
  void join(String sessionId) {
    if (isClosed || state.inCall) {
      return;
    }
    final bool known = switch (state.sessions) {
      ViewSuccess<List<ConsultationSession>>(
        data: final List<ConsultationSession> sessions,
      ) =>
        sessions.any((ConsultationSession s) => s.id == sessionId),
      ViewLoading() ||
      ViewEmpty() ||
      ViewError() ||
      ViewOffline() ||
      ViewUnauthorized() => false,
    };
    if (!known) {
      return;
    }
    emit(state.copyWith(joinedSessionId: sessionId));
  }

  /// Leaves the demo call and returns to the list. Idempotent.
  void leave() {
    if (isClosed) {
      return;
    }
    emit(state.copyWith(joinedSessionId: null));
  }
}
