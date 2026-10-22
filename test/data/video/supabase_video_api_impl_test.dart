import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/video/supabase_video_api.dart';
import 'package:legalhub/data/video/supabase_video_api_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockFunctionCaller extends Mock {
  Future<Object?> call(String function, Map<String, dynamic> body);
}

class _MockRpcCaller extends Mock {
  Future<PostgrestResponse<dynamic>> call(
    String function,
    Map<String, dynamic> params,
  );
}

Matcher _failsWith(SupabaseVideoFailureKind kind) => throwsA(
  isA<SupabaseVideoException>().having(
    (SupabaseVideoException e) => e.kind,
    'kind',
    kind,
  ),
);

PostgrestResponse<dynamic> _response(Object? data) =>
    PostgrestResponse<dynamic>(data: data, count: 0);

void main() {
  late _MockFunctionCaller functionCaller;
  late _MockRpcCaller rpcCaller;
  late SupabaseVideoApi api;

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    functionCaller = _MockFunctionCaller();
    rpcCaller = _MockRpcCaller();
    api = SupabaseVideoApiImpl(
      functionCaller: functionCaller.call,
      rpcCaller: rpcCaller.call,
    );
  });

  group('SupabaseVideoApiImpl RPC contract (design §6)', () {
    test('listSessions sends p_organization_id and returns the rows', () async {
      when(() => rpcCaller('list_video_sessions', any())).thenAnswer(
        (_) async => _response(<Map<String, dynamic>>[
          <String, dynamic>{'id': 'v1'},
        ]),
      );

      final List<Map<String, dynamic>> rows = await api.listSessions(
        organizationId: 'org-1',
      );

      expect(rows.single['id'], 'v1');
      verify(
        () => rpcCaller('list_video_sessions', <String, dynamic>{
          'p_organization_id': 'org-1',
        }),
      ).called(1);
    });

    test(
      'createSession sends the exact named params and UTC schedule',
      () async {
        when(
          () => rpcCaller('create_video_session', any()),
        ).thenAnswer((_) async => _response('v-new'));

        final String id = await api.createSession(
          organizationId: 'org-1',
          matterId: 'matter-1',
          scheduledAt: DateTime.utc(2026, 10, 25, 10),
        );

        expect(id, 'v-new');
        final Map<String, dynamic> params =
            verify(
                  () => rpcCaller('create_video_session', captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        expect(params, <String, dynamic>{
          'p_organization_id': 'org-1',
          'p_matter_id': 'matter-1',
          'p_booking_id': null,
          'p_scheduled_at': '2026-10-25T10:00:00.000Z',
        });
      },
    );

    test(
      'createSession rejects a non-id response as validation drift',
      () async {
        when(
          () => rpcCaller('create_video_session', any()),
        ).thenAnswer((_) async => _response(null));

        await expectLater(
          api.createSession(organizationId: 'org-1'),
          _failsWith(SupabaseVideoFailureKind.validation),
        );
      },
    );

    test('markLive and end send p_id', () async {
      when(
        () => rpcCaller('mark_video_session_live', any()),
      ).thenAnswer((_) async => _response(null));
      when(
        () => rpcCaller('end_video_session', any()),
      ).thenAnswer((_) async => _response(null));

      await api.markLive('v1');
      await api.end('v1');

      verify(
        () => rpcCaller('mark_video_session_live', <String, dynamic>{
          'p_id': 'v1',
        }),
      ).called(1);
      verify(
        () => rpcCaller('end_video_session', <String, dynamic>{'p_id': 'v1'}),
      ).called(1);
    });

    test(
      'RPC denials and transitions classify from the server message',
      () async {
        when(
          () => rpcCaller('list_video_sessions', any()),
        ).thenThrow(const PostgrestException(message: 'permission denied'));
        when(() => rpcCaller('mark_video_session_live', any())).thenThrow(
          const PostgrestException(message: 'video session is not scheduled'),
        );
        when(() => rpcCaller('end_video_session', any())).thenThrow(
          const PostgrestException(message: 'video session has already ended'),
        );

        await expectLater(
          api.listSessions(organizationId: 'org-1'),
          _failsWith(SupabaseVideoFailureKind.forbidden),
        );
        await expectLater(
          api.markLive('v1'),
          _failsWith(SupabaseVideoFailureKind.validation),
        );
        await expectLater(
          api.end('v1'),
          _failsWith(SupabaseVideoFailureKind.sessionEnded),
        );
      },
    );
  });

  group('SupabaseVideoApiImpl video-token contract (plan §Token contract)', () {
    test('invokes video-token with session_id and returns the body', () async {
      when(() => functionCaller('video-token', any())).thenAnswer(
        (_) async => <String, dynamic>{
          'url': 'wss://livekit.example',
          'token': 'jwt-token',
          'room': 'room_abcdef0123456789',
        },
      );

      final Map<String, dynamic> payload = await api.fetchToken('v1');

      expect(payload['url'], 'wss://livekit.example');
      expect(payload['room'], 'room_abcdef0123456789');
      verify(
        () => functionCaller('video-token', <String, dynamic>{
          'session_id': 'v1',
        }),
      ).called(1);
    });

    test('the wire error code is authoritative', () async {
      when(() => functionCaller('video-token', any())).thenThrow(
        const FunctionException(
          status: 409,
          details: <String, dynamic>{'error': 'provider_not_configured'},
        ),
      );

      await expectLater(
        api.fetchToken('v1'),
        _failsWith(SupabaseVideoFailureKind.providerNotConfigured),
      );
    });

    test('maps every token error code', () async {
      const Map<String, SupabaseVideoFailureKind> cases =
          <String, SupabaseVideoFailureKind>{
            'unauthorized': SupabaseVideoFailureKind.unauthorized,
            'forbidden': SupabaseVideoFailureKind.forbidden,
            'session_not_found': SupabaseVideoFailureKind.notFound,
            'session_ended': SupabaseVideoFailureKind.sessionEnded,
            'provider_not_configured':
                SupabaseVideoFailureKind.providerNotConfigured,
            'internal_error': SupabaseVideoFailureKind.unknown,
          };
      for (final MapEntry<String, SupabaseVideoFailureKind> entry
          in cases.entries) {
        when(() => functionCaller('video-token', any())).thenThrow(
          FunctionException(
            status: 500,
            details: <String, dynamic>{'error': entry.key},
          ),
        );
        await expectLater(api.fetchToken('v1'), _failsWith(entry.value));
      }
    });

    test('falls back to the HTTP status when the body is stripped', () async {
      when(
        () => functionCaller('video-token', any()),
      ).thenThrow(const FunctionException(status: 404));
      await expectLater(
        api.fetchToken('v1'),
        _failsWith(SupabaseVideoFailureKind.notFound),
      );

      when(
        () => functionCaller('video-token', any()),
      ).thenThrow(const FunctionException(status: 409));
      await expectLater(
        api.fetchToken('v1'),
        _failsWith(SupabaseVideoFailureKind.providerNotConfigured),
      );
    });

    test('a non-object token payload is typed drift', () async {
      when(
        () => functionCaller('video-token', any()),
      ).thenAnswer((_) async => 'not-a-map');

      await expectLater(
        api.fetchToken('v1'),
        _failsWith(SupabaseVideoFailureKind.unknown),
      );
    });
  });
}
