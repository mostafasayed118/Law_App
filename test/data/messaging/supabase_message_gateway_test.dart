import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/messaging/supabase_message_api.dart';
import 'package:legalhub/data/messaging/supabase_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';

/// Hand-rolled fake of the [SupabaseMessageApi] seam: records calls and
/// answers with canned rows or a [SupabaseMessageException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseMessageApi implements SupabaseMessageApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> messageRows = <Map<String, dynamic>>[];
  SupabaseMessageException? error;
  final List<String> messageFetches = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetchMessageThreads() async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async {
    messageFetches.add(threadId);
    if (error != null) {
      throw error!;
    }
    return messageRows;
  }
}

Map<String, dynamic> _messageRow({
  String id = 'msg-1',
  String threadId = 'thread-1',
  String author = 'Demo attorney',
  String body =
      'Demo message 1 — generic demo content, no real client or '
      'legal data.',
  String sentAt = '2026-08-07T10:00:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'thread_id': threadId,
  'author_display_name': author,
  'body': body,
  'sent_at': sentAt,
};

Map<String, dynamic> _row({
  String id = 'thread-1',
  String matterId = 'm-1',
  String title = 'Demo matter updates',
  Object? participants = const <String>['Layla Mansour', 'Demo client'],
  int messageCount = 3,
  Object? matters = const <String, dynamic>{'title': 'Demo acquisition review'},
  String lastActivityAt = '2026-08-07T10:00:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'matter_id': matterId,
  'title': title,
  'participants': participants,
  'message_count': messageCount,
  'last_activity_at': lastActivityAt,
  'matters': matters,
};

void main() {
  late _StubSupabaseMessageApi api;
  late SupabaseMessageGateway gateway;

  setUp(() {
    api = _StubSupabaseMessageApi();
    gateway = SupabaseMessageGateway(api);
  });

  group('row → MessageThread mapping (D-MSR7)', () {
    test('maps a full row to the MessageThread VO with the embedded matter '
        'title', () async {
      api.rows = <Map<String, dynamic>>[_row()];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isTrue);
      final MessageThread thread = result.valueOrNull!.single;
      expect(thread.id, 'thread-1');
      expect(thread.title, 'Demo matter updates');
      expect(thread.matterRef, 'Demo acquisition review');
      expect(thread.participants, <String>['Layla Mansour', 'Demo client']);
      expect(thread.messageCount, 3);
      expect(
        thread.lastActivityAt,
        DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
      );
    });

    test(
      'maps the participants text[] column to an unmodifiable list',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(participants: const <String>['Omar Farouk']),
        ];

        final MessageThread thread =
            (await gateway.fetchThreads()).valueOrNull!.single;

        expect(thread.participants, <String>['Omar Farouk']);
        // The VO's participants must never be mutated by a consumer (the
        // fake's determinism pin); the real path serves fresh unmodifiable
        // lists per fetch.
        expect(
          () => thread.participants.add('Someone else'),
          throwsUnsupportedError,
        );
      },
    );

    test('maps an empty participants array to an empty list', () async {
      api.rows = <Map<String, dynamic>>[_row(participants: const <String>[])];

      final MessageThread thread =
          (await gateway.fetchThreads()).valueOrNull!.single;

      expect(thread.participants, isEmpty);
    });

    test(
      'resolves matterRef from the embedded matters(title) select (D-MSR4)',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(
            matterId: 'm-9',
            matters: <String, dynamic>{'title': 'Lease review'},
          ),
        ];

        final MessageThread thread =
            (await gateway.fetchThreads()).valueOrNull!.single;

        expect(thread.matterRef, 'Lease review');
      },
    );

    test(
      'falls back to the raw matter id when the embed is absent (D-MSR4)',
      () async {
        api.rows = <Map<String, dynamic>>[_row(matters: null)];

        final MessageThread thread =
            (await gateway.fetchThreads()).valueOrNull!.single;

        expect(thread.matterRef, 'm-1');
      },
    );

    test(
      'falls back to the raw matter id when the embed title is empty',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(matters: <String, dynamic>{'title': ''}),
        ];

        final MessageThread thread =
            (await gateway.fetchThreads()).valueOrNull!.single;

        expect(thread.matterRef, 'm-1');
      },
    );

    test('parses last_activity_at and converts to local time', () async {
      api.rows = <Map<String, dynamic>>[_row()];

      final MessageThread thread =
          (await gateway.fetchThreads()).valueOrNull!.single;

      expect(
        thread.lastActivityAt,
        DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
      );
    });

    test('returns an empty success for no rows', () async {
      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('loud provider-drift handling', () {
    test('a missing title fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'thread-1', 'matter_id': 'm-1'},
      ];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('a missing matter_id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'thread-1', 'title': 'Demo matter updates'},
      ];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('a missing id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'matter_id': 'm-1', 'title': 'Demo matter updates'},
      ];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('a malformed participants value fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(participants: 'not-a-list')];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('a non-string participant fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        _row(participants: const <Object>[42]),
      ];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('a non-int message_count fails the fetch loudly', () async {
      final Map<String, dynamic> badRow = _row();
      badRow['message_count'] = 'three';
      api.rows = <Map<String, dynamic>>[badRow];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });

    test('an unparseable last_activity_at fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(lastActivityAt: 'not-a-date')];

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_read_failed');
    });
  });

  group('row → Message mapping (D-RT5)', () {
    test('maps a full message row to the Message VO', () async {
      api.messageRows = <Map<String, dynamic>>[
        _messageRow(
          id: 'msg-9',
          threadId: 'thread-2',
          author: 'Demo client',
          body:
              'Demo message 2 — generic demo content, no real client or '
              'legal data.',
          sentAt: '2026-08-07T11:00:00.000Z',
        ),
      ];

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-2',
      );

      expect(result.isSuccess, isTrue);
      expect(api.messageFetches, <String>['thread-2']);
      final Message message = result.valueOrNull!.single;
      expect(message.id, 'msg-9');
      expect(message.authorDisplayName, 'Demo client');
      expect(message.body, contains('generic demo content'));
      expect(
        message.sentAt,
        DateTime.parse('2026-08-07T11:00:00.000Z').toLocal(),
      );
    });

    test('returns an empty success for no rows', () async {
      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('a missing id fails the fetch loudly', () async {
      api.messageRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'author_display_name': 'Demo attorney',
          'body': 'Demo message',
          'sent_at': '2026-08-07T10:00:00.000Z',
        },
      ];

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_body_read_failed');
    });

    test('a missing body fails the fetch loudly', () async {
      api.messageRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg-1',
          'author_display_name': 'Demo attorney',
          'sent_at': '2026-08-07T10:00:00.000Z',
        },
      ];

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_body_read_failed');
    });

    test('a missing author fails the fetch loudly', () async {
      api.messageRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg-1',
          'body': 'Demo message',
          'sent_at': '2026-08-07T10:00:00.000Z',
        },
      ];

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_body_read_failed');
    });

    test('an unparseable sent_at fails the fetch loudly', () async {
      api.messageRows = <Map<String, dynamic>>[
        _messageRow(sentAt: 'not-a-date'),
      ];

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'message_body_read_failed');
    });
  });

  group('messages failure mapping (contract §5, D-RT5)', () {
    test('maps a denied read to the message_body denied code', () async {
      api.error = const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<Message>> result = await gateway.fetchMessages(
        'thread-1',
      );

      final AppError error = result.errorOrNull!;
      expect(error.code, 'message_body_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unavailable read to the message_body unavailable code',
      () async {
        api.error = const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.providerUnavailable,
          message: 'Provider unavailable.',
        );

        final Result<List<Message>> result = await gateway.fetchMessages(
          'thread-1',
        );

        final AppError error = result.errorOrNull!;
        expect(error.code, 'message_body_read_unavailable');
        expect(error.technicalMessage, 'Provider unavailable.');
      },
    );

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.unknown,
          message: 'provider hiccup',
        );

        final Result<List<Message>> result = await gateway.fetchMessages(
          'thread-1',
        );

        final AppError error = result.errorOrNull!;
        expect(error.code, 'message_body_read_failed');
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.context, isEmpty);
      },
    );
  });

  group('failure mapping (contract §5)', () {
    test('maps a denied read to the denied AppError code', () async {
      api.error = const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'message_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseMessageException(
          kind: SupabaseMessageFailureKind.unknown,
          message: 'provider hiccup',
        );

        final Result<List<MessageThread>> result = await gateway.fetchThreads();

        final AppError error = result.errorOrNull!;
        expect(error.code, 'message_read_failed');
        // The failure path never touches row content (the seam throws before
        // mapping runs) and the AppError context stays empty by construction
        // — only the provider's own message crosses as the technical message.
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.context, isEmpty);
      },
    );

    test('maps an unavailable read to the unavailable AppError code', () async {
      api.error = const SupabaseMessageException(
        kind: SupabaseMessageFailureKind.providerUnavailable,
        message: 'Provider unavailable.',
      );

      final Result<List<MessageThread>> result = await gateway.fetchThreads();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'message_read_unavailable');
      expect(error.technicalMessage, 'Provider unavailable.');
    });
  });
}
