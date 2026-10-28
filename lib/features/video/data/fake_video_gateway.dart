import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

/// Development-only video gateway: a fixed synthetic schedule plus in-memory
/// create/end transitions (design §1.3 — the fake is registered only in
/// env-less builds and ALL tests).
///
/// The one path it deliberately does **not** fake is the call itself:
/// [fetchToken] always fails with `provider_not_configured`, because a
/// deployment without LiveKit secrets must render an honest unavailable state
/// rather than a synthetic call. Ids are obviously non-UUID and never reach a
/// real backend (design §1.2).
class FakeVideoGateway implements VideoGateway {
  /// The fixed synthetic schedule served by [fetchSessions] on a fresh
  /// instance. One row per lifecycle state so the screen's status handling is
  /// exercised end-to-end.
  static final List<VideoSession> syntheticSessions = <VideoSession>[
    VideoSession(
      id: 'video-1',
      organizationId: DemoCorpus.organizationId,
      matterId: DemoCorpus.matterIds[0],
      roomName: 'room_demo000000000001',
      status: VideoSessionStatus.scheduled,
      scheduledAt: DateTime.utc(2026, 10, 25, 10, 0),
      createdBy: DemoCorpus.ownerId,
    ),
    VideoSession(
      id: 'video-2',
      organizationId: DemoCorpus.organizationId,
      roomName: 'room_demo000000000002',
      status: VideoSessionStatus.live,
      scheduledAt: DateTime.utc(2026, 10, 22, 9, 0),
      startedAt: DateTime.utc(2026, 10, 22, 9, 5),
      createdBy: DemoCorpus.attorneyId,
    ),
    VideoSession(
      id: 'video-3',
      organizationId: DemoCorpus.organizationId,
      roomName: 'room_demo000000000003',
      status: VideoSessionStatus.ended,
      scheduledAt: DateTime.utc(2026, 10, 20, 14, 0),
      startedAt: DateTime.utc(2026, 10, 20, 14, 2),
      endedAt: DateTime.utc(2026, 10, 20, 14, 40),
      createdBy: DemoCorpus.ownerId,
    ),
    VideoSession(
      id: 'video-4',
      organizationId: DemoCorpus.organizationId,
      roomName: 'room_demo000000000004',
      status: VideoSessionStatus.cancelled,
      scheduledAt: DateTime.utc(2026, 10, 21, 11, 0),
      createdBy: DemoCorpus.attorneyId,
    ),
  ];

  final List<VideoSession> _sessions = List<VideoSession>.of(syntheticSessions);
  int _nextId = 1;

  @override
  Future<Result<List<VideoSession>>> fetchSessions() async {
    return Result<List<VideoSession>>.success(
      List<VideoSession>.unmodifiable(_sessions),
    );
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    final int number = _nextId++;
    final String id = 'video-local-$number';
    _sessions.add(
      VideoSession(
        id: id,
        organizationId: DemoCorpus.organizationId,
        matterId: matterId,
        bookingId: bookingId,
        roomName: 'room_demo${number.toString().padLeft(16, '0')}',
        status: VideoSessionStatus.scheduled,
        scheduledAt:
            scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
        createdBy: DemoCorpus.ownerId,
      ),
    );
    return Result<String>.success(id);
  }

  /// No fake call surface: the demo deployment has no provider secrets.
  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) async {
    return Result<VideoToken>.failure(
      const AppError(
        code: 'provider_not_configured',
        userMessage:
            'Video calls are not configured for this deployment. No call was started.',
        messageKey:
            AppMessageKey.errVideoCallsAreNotConfiguredForThisDeployment,
        kind: AppErrorKind.unavailable,
      ),
    );
  }

  @override
  Future<Result<void>> markLive(String id) async {
    return _transition(
      id,
      from: const <VideoSessionStatus>{VideoSessionStatus.scheduled},
      to: VideoSessionStatus.live,
      errorCode: 'video_live_invalid',
      errorMessage: 'This consultation can no longer be started.',
      errorKey: AppMessageKey.errThisConsultationCanNoLongerBeStarted,
    );
  }

  @override
  Future<Result<void>> end(String id) async {
    return _transition(
      id,
      from: const <VideoSessionStatus>{
        VideoSessionStatus.scheduled,
        VideoSessionStatus.live,
      },
      to: VideoSessionStatus.ended,
      errorCode: 'video_session_ended',
      errorMessage: 'This consultation can no longer be ended.',
      errorKey: AppMessageKey.errThisConsultationCanNoLongerBeEnded,
    );
  }

  Future<Result<void>> _transition(
    String id, {
    required Set<VideoSessionStatus> from,
    required VideoSessionStatus to,
    required String errorCode,
    required String errorMessage,
    required AppMessageKey errorKey,
  }) async {
    final int index = _sessions.indexWhere((VideoSession s) => s.id == id);
    if (index < 0) {
      return Result<void>.failure(
        const AppError(
          code: 'video_session_not_found',
          userMessage: 'This video consultation was not found.',
          messageKey: AppMessageKey.errThisVideoConsultationWasNotFound,
        ),
      );
    }
    final VideoSession current = _sessions[index];
    if (!from.contains(current.status)) {
      return Result<void>.failure(
        AppError(
          code: errorCode,
          userMessage: errorMessage,
          messageKey: errorKey,
        ),
      );
    }
    final DateTime now = DateTime.now();
    _sessions[index] = current.copyWith(
      status: to,
      startedAt: to == VideoSessionStatus.live ? now : null,
      endedAt: to == VideoSessionStatus.ended ? now : null,
    );
    return const Result<void>.success(null);
  }
}
