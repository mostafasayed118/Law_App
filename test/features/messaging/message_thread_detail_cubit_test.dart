import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/messaging/presentation/message_thread_detail_cubit.dart';
import 'package:legalhub/features/messaging/presentation/message_thread_detail_state.dart';

void main() {
  late _StubMessageGateway gateway;

  setUp(() {
    gateway = _StubMessageGateway();
  });

  group('MessageThreadDetailCubit (D-RT5)', () {
    test('starts loading with no messages', () {
      final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.messages, const ViewLoading<List<Message>>());
    });

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'load resolves the tapped thread to its messages (AC — first '
      'thread-open)',
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) => cubit.load('thread-1'),
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
      verify: (_) => expect(gateway.fetchCalls, <String>['thread-1']),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.success(const <Message>[]),
        ],
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) => cubit.load('thread-1'),
      expect: () => <MessageThreadDetailState>[
        const MessageThreadDetailState(messages: ViewEmpty<List<Message>>()),
      ],
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.failure(_loadFailure),
        ],
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) => cubit.load('thread-1'),
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewError<List<Message>>(_loadFailure),
        ),
      ],
      verify: (_) => expect(gateway.fetchCalls, <String>['thread-1']),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubMessageGateway.withCompleter(),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        final Future<void> first = cubit.load('thread-1');
        await cubit.load('thread-1');
        gateway.completer!.complete(Result<List<Message>>.success(_messages));
        await first;
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
      verify: (_) => expect(gateway.fetchCalls, <String>['thread-1']),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'load after an error retries into a fresh success',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.failure(_loadFailure),
          Result<List<Message>>.success(_messages),
        ],
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.load('thread-1');
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewError<List<Message>>(_loadFailure),
        ),
        const MessageThreadDetailState(messages: ViewLoading<List<Message>>()),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
      verify: (_) =>
          expect(gateway.fetchCalls, <String>['thread-1', 'thread-1']),
    );

    test(
      'a thrown load resets the guard so a retry reaches the gateway (N1)',
      () async {
        gateway = _StubMessageGateway(throwFirst: true);
        final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(
          gateway,
        );
        addTearDown(cubit.close);

        await expectLater(cubit.load('thread-1'), throwsA(isA<StateError>()));
        await cubit.load('thread-1');

        expect(gateway.fetchCalls, <String>['thread-1', 'thread-1']);
        expect(cubit.state.messages, ViewSuccess<List<Message>>(_messages));
      },
    );
  });

  group('MessageThreadDetailCubit live delivery (D-LV4)', () {
    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a delivered insert appends to the loaded list',
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.subscribe('thread-1');
        gateway.live.add(
          MessageLiveInsert(
            Message(
              id: 'thread-1-msg-live',
              authorDisplayName: 'Demo attorney',
              body: 'Demo live body',
              sentAt: DateTime.utc(2026, 8, 8),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(<Message>[
            ..._messages,
            Message(
              id: 'thread-1-msg-live',
              authorDisplayName: 'Demo attorney',
              body: 'Demo live body',
              sentAt: DateTime.utc(2026, 8, 8),
            ),
          ]),
        ),
      ],
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a delivered row already present is deduped by id',
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.subscribe('thread-1');
        // Deliver the SAME id the loaded list already holds — the writer's
        // own send arrives on the live channel too; the double-add is the
        // expected case and must not duplicate the row.
        gateway.live.add(MessageLiveInsert(_messages.first));
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a reconnect signal re-backfills via the shipped read',
      // The backfill is a second load — the stub needs a second queued
      // result (the shipped read IS the backfill, never a second mechanism).
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.success(_messages),
          Result<List<Message>>.success(_messages),
        ],
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.subscribe('thread-1');
        gateway.live.add(const MessageLiveReconnected());
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        const MessageThreadDetailState(messages: ViewLoading<List<Message>>()),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
      verify: (_) =>
          expect(gateway.fetchCalls, <String>['thread-1', 'thread-1']),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a live insert during error is buffered and merged on retry',
      // First load fails (error state), the live row arrives mid-error, then
      // the retry succeeds — the merged list holds both, deduped by id.
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.failure(_loadFailure),
          Result<List<Message>>.success(_messages),
        ],
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.subscribe('thread-1');
        gateway.live.add(
          MessageLiveInsert(
            Message(
              id: 'thread-1-msg-live',
              authorDisplayName: 'Demo attorney',
              body: 'Demo live body',
              sentAt: DateTime.utc(2026, 8, 8),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await cubit.load('thread-1');
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewError<List<Message>>(_loadFailure),
        ),
        const MessageThreadDetailState(messages: ViewLoading<List<Message>>()),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(<Message>[
            ..._messages,
            Message(
              id: 'thread-1-msg-live',
              authorDisplayName: 'Demo attorney',
              body: 'Demo live body',
              sentAt: DateTime.utc(2026, 8, 8),
            ),
          ]),
        ),
      ],
    );

    test('live inserts retain at most 200 messages', () async {
      final _StubMessageGateway stub = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.success(
            List<Message>.generate(
              200,
              (int i) => Message(
                id: 'm-$i',
                authorDisplayName: 'A',
                body: 'body-$i',
                sentAt: DateTime.utc(2026, 8, 8).add(Duration(minutes: i)),
              ),
            ),
          ),
        ],
      );
      final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(stub);
      addTearDown(cubit.close);

      await cubit.load('thread-1');
      await cubit.subscribe('thread-1');

      stub.live.add(
        MessageLiveInsert(
          Message(
            id: 'm-new',
            authorDisplayName: 'A',
            body: 'newest',
            sentAt: DateTime.utc(2026, 8, 9),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final List<Message> messages =
          (cubit.state.messages as ViewSuccess<List<Message>>).data;
      expect(messages, hasLength(200));
      expect(messages.last.id, 'm-new');
      expect(messages.first.id, 'm-1');
    });

    test('subscribe then close cancels the live subscription', () async {
      final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(gateway);
      await cubit.load('thread-1');
      await cubit.subscribe('thread-1');

      await cubit.close();

      // Delivering after close must not emit (the subscription is dead).
      gateway.live.add(
        MessageLiveInsert(
          Message(
            id: 'thread-1-msg-late',
            authorDisplayName: 'Demo attorney',
            body: 'Late',
            sentAt: DateTime.utc(2026, 8, 8),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.messages, isA<ViewSuccess<List<Message>>>());
      expect(
        (cubit.state.messages as ViewSuccess<List<Message>>).data,
        hasLength(_messages.length),
      );
    });
  });

  group('MessageThreadDetailCubit send (D-LV1)', () {
    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a successful send appends the persisted row and clears sending',
      setUp: () => gateway.sendResult = Result<Message>.success(
        Message(
          id: 'thread-1-sent-7',
          authorDisplayName: 'Demo Partner',
          body: 'A demo send',
          sentAt: DateTime.utc(2026, 8, 8),
        ),
      ),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.send(
          'thread-1',
          'A demo send',
          authorDisplayName: 'Demo Partner',
        );
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sending: true,
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(<Message>[
            ..._messages,
            Message(
              id: 'thread-1-sent-7',
              authorDisplayName: 'Demo Partner',
              body: 'A demo send',
              sentAt: DateTime.utc(2026, 8, 8),
            ),
          ]),
        ),
      ],
      verify: (_) {
        expect(gateway.sendCalls, 1);
        expect(gateway.sentThreadId, 'thread-1');
        expect(gateway.sentBody, 'A demo send');
        expect(gateway.sentAuthor, 'Demo Partner');
      },
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a failed send surfaces sendError and clears sending',
      setUp: () => gateway.sendResult = Result<Message>.failure(_sendFailure),
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.send('thread-1', 'A demo send');
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sending: true,
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sendError: _sendFailure,
        ),
      ],
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a thrown send surfaces the failure state and re-enables the composer (N1)',
      setUp: () => gateway.throwOnSend = true,
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.send('thread-1', 'A demo send');
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sending: true,
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sendError: _sendFailure,
        ),
      ],
      verify: (_) => expect(gateway.sendCalls, 1),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'a whitespace-only send never hits the gateway',
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.send('thread-1', '   ');
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
      ],
      verify: (_) => expect(gateway.sendCalls, 0),
    );

    blocTest<MessageThreadDetailCubit, MessageThreadDetailState>(
      'an oversized send surfaces sendError without a round-trip',
      build: () => MessageThreadDetailCubit(gateway),
      act: (MessageThreadDetailCubit cubit) async {
        await cubit.load('thread-1');
        await cubit.send('thread-1', 'x' * 2001);
      },
      expect: () => <MessageThreadDetailState>[
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
        ),
        MessageThreadDetailState(
          messages: ViewSuccess<List<Message>>(_messages),
          sendError: const AppError(
            code: 'message_too_long',
            userMessage: 'Message is too long (max 2000 characters).',
            messageKey:
                AppMessageKey.errMessageIsTooLongMaxMaxMessageLengthCharacters,
            messageArgs: <String, Object?>{'maxMessageLength': 2000},
          ),
        ),
      ],
      verify: (_) => expect(gateway.sendCalls, 0),
    );

    test('a send after a full window keeps the newest 200', () async {
      final _StubMessageGateway stub = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.success(
            List<Message>.generate(
              200,
              (int i) => Message(
                id: 'm-$i',
                authorDisplayName: 'A',
                body: 'body-$i',
                sentAt: DateTime.utc(2026, 8, 8).add(Duration(minutes: i)),
              ),
            ),
          ),
        ],
      );
      stub.sendResult = Result<Message>.success(
        Message(
          id: 'm-new',
          authorDisplayName: 'A',
          body: 'newest',
          sentAt: DateTime.utc(2026, 8, 9),
        ),
      );
      final MessageThreadDetailCubit cubit = MessageThreadDetailCubit(stub);
      addTearDown(cubit.close);

      await cubit.load('thread-1');
      await cubit.send('thread-1', 'newest');

      final List<Message> messages =
          (cubit.state.messages as ViewSuccess<List<Message>>).data;
      expect(messages, hasLength(200));
      expect(messages.last.id, 'm-new');
      expect(messages.first.id, 'm-1');
    });
  });
}

final AppError _sendFailure = AppError(
  code: 'message_send_failed',
  userMessage: 'Unable to send the message. Please try again.',
);

final List<Message> _messages = <Message>[
  Message(
    id: 'thread-1-msg-1',
    authorDisplayName: 'Demo attorney',
    body:
        'Demo message 1 — generic demo content, no real client or legal '
        'data.',
    sentAt: DateTime.utc(2026, 7, 28),
  ),
  Message(
    id: 'thread-1-msg-2',
    authorDisplayName: 'Demo client',
    body:
        'Demo message 2 — generic demo content, no real client or legal '
        'data.',
    sentAt: DateTime.utc(2026, 7, 28, 1),
  ),
];

final AppError _loadFailure = AppError(
  code: 'message_body_read_failed',
  userMessage: 'Unable to load messages.',
);

/// Hand-rolled gateway stub: queue of message results (like the thread-list
/// stub), or a Completer for in-flight tests; a scriptable live stream and
/// a scriptable send result for the D-LV1/D-LV4 paths.
class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway({
    List<Result<List<Message>>>? results,
    this.throwFirst = false,
  }) : _queue = results == null
           ? <Result<List<Message>>>[Result<List<Message>>.success(_messages)]
           : List<Result<List<Message>>>.of(results),
       completer = null;

  _StubMessageGateway.withCompleter()
    : _queue = const <Result<List<Message>>>[],
      completer = Completer<Result<List<Message>>>(),
      throwFirst = false;

  final List<Result<List<Message>>> _queue;
  final Completer<Result<List<Message>>>? completer;
  final bool throwFirst;
  final List<String> fetchCalls = <String>[];
  final StreamController<MessageRealtimeEvent> live =
      StreamController<MessageRealtimeEvent>.broadcast();
  bool throwOnSend = false;
  Result<Message> sendResult = Result<Message>.success(
    Message(
      id: 'thread-1-sent-1',
      authorDisplayName: 'Demo client',
      body: 'Sent body',
      sentAt: DateTime.utc(2026, 8, 8),
    ),
  );
  int sendCalls = 0;
  String? sentThreadId;
  String? sentBody;
  String? sentAuthor;
  int subscriptionCancels = 0;

  @override
  Future<Result<List<MessageThread>>> fetchThreads({String? matterId}) async {
    // Not exercised by the detail cubit tests.
    return const Result<List<MessageThread>>.success(<MessageThread>[]);
  }

  @override
  Future<Result<List<MessageThread>>> searchThreads(
    String query, {
    int limit = 30,
  }) => fetchThreads();

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) {
    fetchCalls.add(threadId);
    if (throwFirst && fetchCalls.length == 1) {
      throw StateError('message body gateway blew up');
    }
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Message>>>.value(_queue.removeAt(0));
  }

  @override
  Future<Result<Message>> sendMessage(
    String threadId,
    String body, {
    String? authorDisplayName,
  }) async {
    sendCalls++;
    sentThreadId = threadId;
    sentBody = body;
    sentAuthor = authorDisplayName;
    if (throwOnSend) {
      throw StateError('send gateway blew up');
    }
    return sendResult;
  }

  @override
  Stream<MessageRealtimeEvent> watchMessages(String threadId) {
    return live.stream;
  }
}
