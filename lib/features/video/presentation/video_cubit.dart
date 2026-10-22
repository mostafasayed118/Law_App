import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../domain/video_gateway.dart';
import '../domain/video_session.dart';
import '../domain/video_token.dart';
import 'video_state.dart';

/// Owns the video-consultation surface's reads and lifecycle writes.
///
/// [load] reads the active organization's sessions and orders them live →
/// scheduled → ended → cancelled. [fetchToken] is the join authorisation
/// step; [create] / [end] return the typed [AppError] on failure and null on
/// success so the sheet and the confirm dialog can render localized inline
/// copy. [loadMatters] feeds the create sheet's optional matter picker.
class VideoCubit extends Cubit<VideoState> {
  VideoCubit(this._gateway, this._matterGateway) : super(const VideoState());

  final VideoGateway _gateway;
  final MatterGateway _matterGateway;

  /// Monotonic request id (the approvals/SearchCubit pattern): a reload
  /// triggered by a write must not be overwritten by an older read.
  int _request = 0;

  bool _acting = false;

  Future<void> load() async {
    final int request = ++_request;
    if (state.sessions is! ViewLoading<List<VideoSession>>) {
      emit(state.copyWith(sessions: const ViewLoading<List<VideoSession>>()));
    }
    final Result<List<VideoSession>> result = await _gateway.fetchSessions();
    if (isClosed || request != _request) {
      return;
    }
    switch (result) {
      case Success<List<VideoSession>>(
        value: final List<VideoSession> sessions,
      ):
        emit(
          state.copyWith(
            sessions: sessions.isEmpty
                ? const ViewEmpty<List<VideoSession>>()
                : ViewSuccess<List<VideoSession>>(_ordered(sessions)),
          ),
        );
      case Failure<List<VideoSession>>(error: final AppError error):
        emit(
          state.copyWith(
            sessions: viewStateForFailure<List<VideoSession>>(error),
          ),
        );
    }
  }

  Future<Result<List<Matter>>> loadMatters() => _matterGateway.fetchMatters();

  /// Fetches the room token for [sessionId] (the join authorisation step).
  Future<Result<VideoToken>> fetchToken(String sessionId) =>
      _gateway.fetchToken(sessionId);

  Future<AppError?> create({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<String> result = await _gateway.createSession(
      matterId: _trimOrNull(matterId),
      bookingId: _trimOrNull(bookingId),
      scheduledAt: scheduledAt,
    );
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<String>():
        await load();
        return null;
      case Failure<String>(error: final AppError error):
        return error;
    }
  }

  /// Ends [id]. Returns null on success, the failure's [AppError] otherwise.
  Future<AppError?> end(String id) async {
    if (isClosed || _acting) {
      return null;
    }
    _acting = true;
    final Result<void> result = await _gateway.end(id);
    _acting = false;
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Success<void>():
        await load();
        return null;
      case Failure<void>(error: final AppError error):
        return error;
    }
  }

  /// Live first, then upcoming (soonest first), then ended/cancelled
  /// (most recent first). Id is the deterministic tie-break.
  List<VideoSession> _ordered(List<VideoSession> sessions) {
    final List<VideoSession> ordered = List<VideoSession>.of(sessions);
    ordered.sort((VideoSession a, VideoSession b) {
      final int rank = _rank(a.status).compareTo(_rank(b.status));
      if (rank != 0) {
        return rank;
      }
      final DateTime? aDate = a.scheduledAt ?? a.startedAt ?? a.endedAt;
      final DateTime? bDate = b.scheduledAt ?? b.startedAt ?? b.endedAt;
      if (aDate != null && bDate != null) {
        final int byDate = a.status == VideoSessionStatus.scheduled
            ? aDate.compareTo(bDate)
            : bDate.compareTo(aDate);
        if (byDate != 0) {
          return byDate;
        }
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    return ordered;
  }

  int _rank(VideoSessionStatus status) => switch (status) {
    VideoSessionStatus.live => 0,
    VideoSessionStatus.scheduled => 1,
    VideoSessionStatus.ended => 2,
    VideoSessionStatus.cancelled => 3,
  };

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
