import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
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
  });
}

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
/// stub), or a Completer for in-flight tests.
class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway({List<Result<List<Message>>>? results})
    : _queue = results == null
          ? <Result<List<Message>>>[Result<List<Message>>.success(_messages)]
          : List<Result<List<Message>>>.of(results),
      completer = null;

  _StubMessageGateway.withCompleter()
    : _queue = const <Result<List<Message>>>[],
      completer = Completer<Result<List<Message>>>();

  final List<Result<List<Message>>> _queue;
  final Completer<Result<List<Message>>>? completer;
  final List<String> fetchCalls = <String>[];

  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    // Not exercised by the detail cubit tests.
    return const Result<List<MessageThread>>.success(<MessageThread>[]);
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) {
    fetchCalls.add(threadId);
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<Message>>>.value(_queue.removeAt(0));
  }
}
