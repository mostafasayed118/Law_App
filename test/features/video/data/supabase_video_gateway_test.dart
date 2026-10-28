import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/video/data/supabase_video_api.dart';
import 'package:legalhub/features/video/data/supabase_video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';

class _StubVideoApi implements SupabaseVideoApi {
  List<Map<String, dynamic>> listRows = <Map<String, dynamic>>[];
  SupabaseVideoException? listError;
  SupabaseVideoException? createError;
  SupabaseVideoException? tokenError;
  SupabaseVideoException? liveError;
  SupabaseVideoException? endError;

  String lastOrganizationId = '';
  String? lastMatterId;
  String? lastBookingId;
  DateTime? lastScheduledAt;
  String lastSessionId = '';
  String lastLiveId = '';
  String lastEndId = '';

  @override
  Future<List<Map<String, dynamic>>> listSessions({
    required String organizationId,
  }) async {
    lastOrganizationId = organizationId;
    if (listError != null) {
      throw listError!;
    }
    return listRows;
  }

  @override
  Future<String> createSession({
    required String organizationId,
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    lastOrganizationId = organizationId;
    lastMatterId = matterId;
    lastBookingId = bookingId;
    lastScheduledAt = scheduledAt;
    if (createError != null) {
      throw createError!;
    }
    return 'v-new';
  }

  @override
  Future<Map<String, dynamic>> fetchToken(String sessionId) async {
    lastSessionId = sessionId;
    if (tokenError != null) {
      throw tokenError!;
    }
    return <String, dynamic>{
      'url': 'wss://livekit.example',
      'token': 'jwt-token',
      'room': 'room_abcdef0123456789',
    };
  }

  @override
  Future<void> markLive(String id) async {
    lastLiveId = id;
    if (liveError != null) {
      throw liveError!;
    }
  }

  @override
  Future<void> end(String id) async {
    lastEndId = id;
    if (endError != null) {
      throw endError!;
    }
  }
}

Map<String, dynamic> _row({
  String id = 'v1',
  String status = 'scheduled',
  String roomName = 'room_abcdef0123456789',
  String? matterId,
  String? bookingId,
  String? scheduledAt = '2026-10-25T10:00:00Z',
  String? startedAt,
  String? endedAt,
  String? createdBy = 'user-1',
}) {
  return <String, dynamic>{
    'id': id,
    'organization_id': 'org-1',
    'matter_id': matterId,
    'booking_id': bookingId,
    'room_name': roomName,
    'status': status,
    'scheduled_at': scheduledAt,
    'started_at': startedAt,
    'ended_at': endedAt,
    'created_by': createdBy,
    'created_at': '2026-10-22T10:00:00Z',
  };
}

void main() {
  late _StubVideoApi api;
  late SupabaseVideoGateway gateway;

  setUp(() {
    api = _StubVideoApi();
    gateway = SupabaseVideoGateway(api, organizationId: () => 'org-1');
  });

  group('SupabaseVideoGateway.fetchSessions (design §6)', () {
    test('maps a full row, including the creator for the end gate', () async {
      api.listRows = <Map<String, dynamic>>[
        _row(
          status: 'live',
          matterId: 'matter-1',
          bookingId: 'booking-1',
          startedAt: '2026-10-22T10:05:00Z',
        ),
      ];

      final Result<List<VideoSession>> result = await gateway.fetchSessions();

      final VideoSession session = result.valueOrNull!.single;
      expect(session.id, 'v1');
      expect(session.organizationId, 'org-1');
      expect(session.matterId, 'matter-1');
      expect(session.bookingId, 'booking-1');
      expect(session.roomName, 'room_abcdef0123456789');
      expect(session.status, VideoSessionStatus.live);
      expect(session.scheduledAt, DateTime.utc(2026, 10, 25, 10));
      expect(session.startedAt, DateTime.utc(2026, 10, 22, 10, 5));
      expect(session.endedAt, isNull);
      expect(session.createdBy, 'user-1');
      expect(session.isJoinable, isTrue);
      expect(api.lastOrganizationId, 'org-1');
    });

    test('maps every lifecycle status', () async {
      api.listRows = <Map<String, dynamic>>[
        _row(id: 'v1', status: 'scheduled'),
        _row(id: 'v2', status: 'live'),
        _row(id: 'v3', status: 'ended', endedAt: '2026-10-22T11:00:00Z'),
        _row(id: 'v4', status: 'cancelled'),
      ];

      final Result<List<VideoSession>> result = await gateway.fetchSessions();

      expect(
        result.valueOrNull!
            .map((VideoSession s) => s.status)
            .toList(growable: false),
        <VideoSessionStatus>[
          VideoSessionStatus.scheduled,
          VideoSessionStatus.live,
          VideoSessionStatus.ended,
          VideoSessionStatus.cancelled,
        ],
      );
      expect(result.valueOrNull![3].isJoinable, isFalse);
    });

    test('requires an active organization', () async {
      gateway = SupabaseVideoGateway(api, organizationId: () => null);

      final Result<List<VideoSession>> result = await gateway.fetchSessions();

      expect(result.errorOrNull!.code, 'video_no_org');
    });

    test('a denial becomes a typed denied AppError', () async {
      api.listError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.forbidden,
        message: 'permission denied',
      );

      final Result<List<VideoSession>> result = await gateway.fetchSessions();

      expect(result.errorOrNull!.code, 'video_forbidden');
      expect(result.errorOrNull!.kind, AppErrorKind.denied);
    });

    test('a malformed room name or status is typed provider drift', () async {
      api.listRows = <Map<String, dynamic>>[_row(roomName: 'room_short')];
      expect(
        (await gateway.fetchSessions()).errorOrNull!.code,
        'video_invalid_response',
      );

      api.listRows = <Map<String, dynamic>>[_row(status: 'paused')];
      expect(
        (await gateway.fetchSessions()).errorOrNull!.code,
        'video_invalid_response',
      );
    });
  });

  group('SupabaseVideoGateway.createSession (design §6)', () {
    test('passes the trimmed references and schedule', () async {
      final Result<String> result = await gateway.createSession(
        matterId: ' matter-1 ',
        bookingId: '  ',
        scheduledAt: DateTime.utc(2026, 10, 25, 10),
      );

      expect(result.valueOrNull, 'v-new');
      expect(api.lastOrganizationId, 'org-1');
      expect(api.lastMatterId, 'matter-1');
      expect(api.lastBookingId, isNull);
      expect(api.lastScheduledAt, DateTime.utc(2026, 10, 25, 10));
    });

    test('a denial is the partner/attorney gate copy', () async {
      api.createError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.forbidden,
        message: 'permission denied',
      );

      final Result<String> result = await gateway.createSession();

      expect(result.errorOrNull!.code, 'video_forbidden');
      expect(result.errorOrNull!.kind, AppErrorKind.denied);
    });

    test('validation maps to the create prefix', () async {
      api.createError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.validation,
        message: 'invalid video session',
      );

      final Result<String> result = await gateway.createSession();

      expect(result.errorOrNull!.code, 'video_create_invalid');
    });
  });

  group('SupabaseVideoGateway.fetchToken (plan §Token contract)', () {
    test('parses url, token, and room', () async {
      final Result<VideoToken> result = await gateway.fetchToken(' v1 ');

      expect(result.valueOrNull!.url, 'wss://livekit.example');
      expect(result.valueOrNull!.token, 'jwt-token');
      expect(result.valueOrNull!.room, 'room_abcdef0123456789');
      expect(api.lastSessionId, 'v1');
    });

    test('provider_not_configured is an honest unavailable state', () async {
      api.tokenError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.providerNotConfigured,
        message: 'missing secrets',
      );

      final Result<VideoToken> result = await gateway.fetchToken('v1');

      expect(result.errorOrNull!.code, 'provider_not_configured');
      expect(result.errorOrNull!.kind, AppErrorKind.unavailable);
    });

    test('ended and missing sessions keep their exact codes', () async {
      api.tokenError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.sessionEnded,
        message: 'ended',
      );
      expect(
        (await gateway.fetchToken('v1')).errorOrNull!.code,
        'video_session_ended',
      );

      api.tokenError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.notFound,
        message: 'missing',
      );
      expect(
        (await gateway.fetchToken('v1')).errorOrNull!.code,
        'video_session_not_found',
      );
    });

    test('a token body missing room is typed drift', () async {
      final _StubVideoApi broken = _BrokenTokenApi();
      final SupabaseVideoGateway brokenGateway = SupabaseVideoGateway(
        broken,
        organizationId: () => 'org-1',
      );

      final Result<VideoToken> result = await brokenGateway.fetchToken('v1');

      expect(result.errorOrNull!.code, 'video_invalid_response');
    });
  });

  group('SupabaseVideoGateway lifecycle writes (design §6)', () {
    test('markLive and end delegate with the trimmed id', () async {
      expect((await gateway.markLive(' v1 ')).isSuccess, isTrue);
      expect((await gateway.end(' v1 ')).isSuccess, isTrue);
      expect(api.lastLiveId, 'v1');
      expect(api.lastEndId, 'v1');
    });

    test('end surfaces the creator/partner denial', () async {
      api.endError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.forbidden,
        message: 'permission denied',
      );

      final Result<void> result = await gateway.end('v1');

      expect(result.errorOrNull!.code, 'video_forbidden');
      expect(result.errorOrNull!.kind, AppErrorKind.denied);
    });

    test('end on a stale row is a validation failure', () async {
      api.endError = const SupabaseVideoException(
        kind: SupabaseVideoFailureKind.validation,
        message: 'video session is not scheduled',
      );

      final Result<void> result = await gateway.end('v1');

      expect(result.errorOrNull!.code, 'video_end_invalid');
    });
  });
}

class _BrokenTokenApi extends _StubVideoApi {
  @override
  Future<Map<String, dynamic>> fetchToken(String sessionId) async {
    return <String, dynamic>{
      'url': 'wss://livekit.example',
      'token': 'jwt-token',
    };
  }
}
