import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/video/domain/consultation_session.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/presentation/video_cubit.dart';
import 'package:legalhub/features/video/presentation/video_state.dart';

final List<ConsultationSession> _sessions = <ConsultationSession>[
  ConsultationSession(
    id: 'video-1',
    participantName: 'Demo attorney — A',
    topic: 'Topic one',
    scheduledAt: DateTime.utc(2026, 9, 24, 10, 0),
  ),
  ConsultationSession(
    id: 'video-2',
    participantName: 'Demo attorney — B',
    topic: 'Topic two',
    scheduledAt: DateTime.utc(2026, 9, 25, 13, 30),
  ),
];

final AppError _loadFailure = AppError(
  code: 'video_failed',
  userMessage: 'Could not load consultations',
);

/// Hand-rolled gateway stub serving one fixed result (the discovery-stub
/// shape, without the queue — the video cubit loads once per surface).
class _StubVideoGateway implements VideoGateway {
  _StubVideoGateway({Result<List<ConsultationSession>>? result})
    : _result = result ?? Result<List<ConsultationSession>>.success(_sessions);

  final Result<List<ConsultationSession>> _result;
  int fetchCalls = 0;

  @override
  Future<Result<List<ConsultationSession>>> fetchSessions() async {
    fetchCalls += 1;
    return _result;
  }
}

void main() {
  late _StubVideoGateway gateway;

  setUp(() {
    gateway = _StubVideoGateway();
  });

  group('VideoCubit (spec D-15 demo-posture)', () {
    test('starts loading and browsing (not in a call)', () {
      final VideoCubit cubit = VideoCubit(gateway);
      addTearDown(cubit.close);

      expect(
        cubit.state.sessions,
        const ViewLoading<List<ConsultationSession>>(),
      );
      expect(cubit.state.joinedSessionId, isNull);
      expect(cubit.state.inCall, isFalse);
    });

    blocTest<VideoCubit, VideoState>(
      'load resolves to the synthetic list',
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<VideoCubit, VideoState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubVideoGateway(
        result: Result<List<ConsultationSession>>.success(
          const <ConsultationSession>[],
        ),
      ),
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        const VideoState(sessions: ViewEmpty<List<ConsultationSession>>()),
      ],
    );

    blocTest<VideoCubit, VideoState>(
      'load maps a failure to ViewError via the shared failure mapping',
      setUp: () => gateway = _StubVideoGateway(
        result: Result<List<ConsultationSession>>.failure(_loadFailure),
      ),
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) => cubit.load(),
      expect: () => <VideoState>[
        VideoState(
          sessions: ViewError<List<ConsultationSession>>(_loadFailure),
        ),
      ],
    );

    blocTest<VideoCubit, VideoState>(
      'join a known session enters the demo call — a pure state transition, '
      'no gateway call (C-3 zero writes)',
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) async {
        await cubit.load();
        cubit.join('video-1');
      },
      expect: () => <VideoState>[
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
        VideoState(
          sessions: ViewSuccess<List<ConsultationSession>>(_sessions),
          joinedSessionId: 'video-1',
        ),
      ],
      verify: (VideoCubit cubit) {
        expect(cubit.state.inCall, isTrue);
        // Joining consumed no extra gateway call.
        expect(gateway.fetchCalls, 1);
      },
    );

    blocTest<VideoCubit, VideoState>(
      'join an unknown session is a no-op (never opens a fabricated call)',
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) async {
        await cubit.load();
        cubit.join('does-not-exist');
      },
      expect: () => <VideoState>[
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
      ],
      verify: (VideoCubit cubit) => expect(cubit.state.inCall, isFalse),
    );

    blocTest<VideoCubit, VideoState>(
      'join while already in a call is a no-op (one call at a time)',
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) async {
        await cubit.load();
        cubit.join('video-1');
        cubit.join('video-2');
      },
      expect: () => <VideoState>[
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
        VideoState(
          sessions: ViewSuccess<List<ConsultationSession>>(_sessions),
          joinedSessionId: 'video-1',
        ),
      ],
      verify: (VideoCubit cubit) =>
          expect(cubit.state.joinedSessionId, 'video-1'),
    );

    blocTest<VideoCubit, VideoState>(
      'leave clears the joined marker and returns to the list (idempotent)',
      build: () => VideoCubit(gateway),
      act: (VideoCubit cubit) async {
        await cubit.load();
        cubit.join('video-1');
        cubit.leave();
        cubit.leave();
      },
      expect: () => <VideoState>[
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
        VideoState(
          sessions: ViewSuccess<List<ConsultationSession>>(_sessions),
          joinedSessionId: 'video-1',
        ),
        VideoState(sessions: ViewSuccess<List<ConsultationSession>>(_sessions)),
      ],
      verify: (VideoCubit cubit) => expect(cubit.state.inCall, isFalse),
    );
  });
}
