import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'package:legalhub/features/video/presentation/video_cubit.dart';
import 'package:legalhub/features/video/presentation/video_state.dart';

class _StubVideoGateway implements VideoGateway {
  List<VideoSession> sessions = <VideoSession>[];
  AppError? loadError;
  AppError? createError;
  AppError? endError;

  int fetchCalls = 0;
  int createCalls = 0;
  int endCalls = 0;
  int tokenCalls = 0;
  String? lastMatterId;
  DateTime? lastScheduledAt;

  @override
  Future<Result<List<VideoSession>>> fetchSessions() async {
    fetchCalls += 1;
    if (loadError != null) {
      return Result<List<VideoSession>>.failure(loadError!);
    }
    return Result<List<VideoSession>>.success(sessions);
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    createCalls += 1;
    lastMatterId = matterId;
    lastScheduledAt = scheduledAt;
    if (createError != null) {
      return Result<String>.failure(createError!);
    }
    return const Result<String>.success('v-new');
  }

  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) async {
    tokenCalls += 1;
    return const Result<VideoToken>.success(
      VideoToken(
        url: 'wss://livekit.example',
        token: 'jwt-token',
        room: 'room_abcdef0123456789',
      ),
    );
  }

  @override
  Future<Result<void>> markLive(String id) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> end(String id) async {
    endCalls += 1;
    if (endError != null) {
      return Result<void>.failure(endError!);
    }
    return const Result<void>.success(null);
  }
}

class _StubMatterGateway implements MatterGateway {
  int fetchCalls = 0;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    fetchCalls += 1;
    return const Result<List<Matter>>.success(<Matter>[]);
  }

  @override
  Future<Result<List<Matter>>> searchMatters(
    String query, {
    int limit = 30,
  }) async {
    return const Result<List<Matter>>.success(<Matter>[]);
  }
}

VideoSession _session({
  required String id,
  required VideoSessionStatus status,
  DateTime? scheduledAt,
}) {
  return VideoSession(
    id: id,
    organizationId: 'org-1',
    roomName: 'room_abcdef0123456789',
    status: status,
    scheduledAt: scheduledAt ?? DateTime.utc(2026, 10, 25),
  );
}

void main() {
  late _StubVideoGateway gateway;
  late _StubMatterGateway matters;

  setUp(() {
    gateway = _StubVideoGateway();
    matters = _StubMatterGateway();
  });

  group('VideoCubit load (design §6)', () {
    test('starts loading', () {
      final VideoCubit cubit = VideoCubit(gateway, matters);
      addTearDown(cubit.close);

      expect(cubit.state.sessions, const ViewLoading<List<VideoSession>>());
    });

    blocTest<VideoCubit, VideoState>(
      'orders live, then upcoming soonest first, then ended and cancelled',
      setUp: () {
        gateway.sessions = <VideoSession>[
          _session(id: 'ended', status: VideoSessionStatus.ended),
          _session(
            id: 'later',
            status: VideoSessionStatus.scheduled,
            scheduledAt: DateTime.utc(2026, 10, 26),
          ),
          _session(id: 'live', status: VideoSessionStatus.live),
          _session(
            id: 'sooner',
            status: VideoSessionStatus.scheduled,
            scheduledAt: DateTime.utc(2026, 10, 24),
          ),
          _session(id: 'cancelled', status: VideoSessionStatus.cancelled),
        ];
      },
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) => cubit.load(),
      verify: (VideoCubit cubit) {
        final List<VideoSession> ordered =
            (cubit.state.sessions as ViewSuccess<List<VideoSession>>).data;
        expect(
          ordered.map((VideoSession s) => s.id).toList(growable: false),
          <String>['live', 'sooner', 'later', 'ended', 'cancelled'],
        );
      },
    );

    blocTest<VideoCubit, VideoState>(
      'an empty list maps to ViewEmpty',
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        const VideoState(sessions: ViewEmpty<List<VideoSession>>()),
      ],
    );

    blocTest<VideoCubit, VideoState>(
      'a denial maps to ViewUnauthorized, not a retryable error',
      setUp: () => gateway.loadError = const AppError(
        code: 'video_forbidden',
        userMessage: 'Denied',
        kind: AppErrorKind.denied,
      ),
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        const VideoState(sessions: ViewUnauthorized<List<VideoSession>>()),
      ],
    );

    blocTest<VideoCubit, VideoState>(
      'a generic failure maps to ViewError',
      setUp: () => gateway.loadError = const AppError(
        code: 'video_read_failed',
        userMessage: 'Failed',
      ),
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        VideoState(sessions: ViewError<List<VideoSession>>(gateway.loadError!)),
      ],
    );
  });

  group('VideoCubit writes (design §6)', () {
    blocTest<VideoCubit, VideoState>(
      'create trims blanks, forwards the schedule, and reloads on success',
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) async {
        final AppError? error = await cubit.create(
          matterId: '  ',
          scheduledAt: DateTime.utc(2026, 11, 1, 9),
        );
        expect(error, isNull);
      },
      verify: (_) {
        expect(gateway.createCalls, 1);
        expect(gateway.lastMatterId, isNull);
        expect(gateway.lastScheduledAt, DateTime.utc(2026, 11, 1, 9));
        expect(gateway.fetchCalls, 1);
      },
    );

    blocTest<VideoCubit, VideoState>(
      'create returns the typed AppError and does not reload',
      setUp: () => gateway.createError = const AppError(
        code: 'video_forbidden',
        userMessage: 'Denied',
        kind: AppErrorKind.denied,
      ),
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) async {
        final AppError? error = await cubit.create(matterId: 'matter-1');
        expect(error!.code, 'video_forbidden');
      },
      verify: (_) => expect(gateway.fetchCalls, 0),
    );

    blocTest<VideoCubit, VideoState>(
      'end returns null on success and reloads',
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) async {
        expect(await cubit.end('v1'), isNull);
      },
      verify: (_) {
        expect(gateway.endCalls, 1);
        expect(gateway.fetchCalls, 1);
      },
    );

    blocTest<VideoCubit, VideoState>(
      'end returns the typed AppError on failure',
      setUp: () => gateway.endError = const AppError(
        code: 'video_end_invalid',
        userMessage: 'Already ended',
      ),
      build: () => VideoCubit(gateway, matters),
      act: (VideoCubit cubit) async {
        final AppError? error = await cubit.end('v1');
        expect(error!.code, 'video_end_invalid');
      },
      verify: (_) => expect(gateway.fetchCalls, 0),
    );

    test('fetchToken delegates the join authorisation step', () async {
      final VideoCubit cubit = VideoCubit(gateway, matters);
      addTearDown(cubit.close);

      final Result<VideoToken> result = await cubit.fetchToken('v1');

      expect(result.valueOrNull!.room, 'room_abcdef0123456789');
      expect(gateway.tokenCalls, 1);
    });

    test('loadMatters delegates to the matter gateway', () async {
      final VideoCubit cubit = VideoCubit(gateway, matters);
      addTearDown(cubit.close);

      final Result<List<Matter>> result = await cubit.loadMatters();

      expect(result.isSuccess, isTrue);
      expect(matters.fetchCalls, 1);
    });
  });
}
