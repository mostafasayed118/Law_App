import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/messaging/presentation/message_cubit.dart';
import 'package:legalhub/features/messaging/presentation/message_state.dart';

void main() {
  late _StubMessageGateway gateway;

  setUp(() {
    gateway = _StubMessageGateway();
  });

  group('MessageCubit (Phase 9 slice 9.1)', () {
    test('starts loading with no threads', () {
      final MessageCubit cubit = MessageCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.threads, const ViewLoading<List<MessageThread>>());
    });

    blocTest<MessageCubit, MessageState>(
      'load resolves to the synthetic metadata list (AC-1)',
      build: () => MessageCubit(gateway),
      act: (MessageCubit cubit) => cubit.load(),
      expect: () => <MessageState>[
        MessageState(threads: ViewSuccess<List<MessageThread>>(_threads)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<MessageCubit, MessageState>(
      'load maps an empty list to ViewEmpty',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<MessageThread>>>[
          Result<List<MessageThread>>.success(const <MessageThread>[]),
        ],
      ),
      build: () => MessageCubit(gateway),
      act: (MessageCubit cubit) => cubit.load(),
      expect: () => <MessageState>[
        const MessageState(threads: ViewEmpty<List<MessageThread>>()),
      ],
    );

    blocTest<MessageCubit, MessageState>(
      'load maps a failure to ViewError',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<MessageThread>>>[
          Result<List<MessageThread>>.failure(_loadFailure),
        ],
      ),
      build: () => MessageCubit(gateway),
      act: (MessageCubit cubit) => cubit.load(),
      expect: () => <MessageState>[
        MessageState(threads: ViewError<List<MessageThread>>(_loadFailure)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<MessageCubit, MessageState>(
      'duplicate load while in flight is ignored',
      setUp: () => gateway = _StubMessageGateway.withCompleter(),
      build: () => MessageCubit(gateway),
      act: (MessageCubit cubit) async {
        final Future<void> first = cubit.load();
        await cubit.load();
        gateway.completer!.complete(
          Result<List<MessageThread>>.success(_threads),
        );
        await first;
      },
      expect: () => <MessageState>[
        MessageState(threads: ViewSuccess<List<MessageThread>>(_threads)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 1),
    );

    blocTest<MessageCubit, MessageState>(
      'load after an error retries into a fresh success (AC-3)',
      setUp: () => gateway = _StubMessageGateway(
        results: <Result<List<MessageThread>>>[
          Result<List<MessageThread>>.failure(_loadFailure),
          Result<List<MessageThread>>.success(_threads),
        ],
      ),
      build: () => MessageCubit(gateway),
      act: (MessageCubit cubit) async {
        await cubit.load();
        await cubit.load();
      },
      expect: () => <MessageState>[
        MessageState(threads: ViewError<List<MessageThread>>(_loadFailure)),
        const MessageState(threads: ViewLoading<List<MessageThread>>()),
        MessageState(threads: ViewSuccess<List<MessageThread>>(_threads)),
      ],
      verify: (_) => expect(gateway.fetchCalls, 2),
    );
  });
}

final List<MessageThread> _threads = <MessageThread>[
  MessageThread(
    id: 'thread-1',
    title: 'Demo matter updates',
    matterRef: 'Demo acquisition review',
    participants: const <String>['Layla Mansour', 'Demo client'],
    lastActivityAt: DateTime.utc(2026, 7, 28),
    messageCount: 12,
  ),
  MessageThread(
    id: 'thread-2',
    title: 'Consultation follow-up — demo',
    matterRef: 'Commercial lease consultation',
    participants: const <String>['Omar Farouk', 'Demo client'],
    lastActivityAt: DateTime.utc(2026, 7, 25),
    messageCount: 8,
  ),
];

final AppError _loadFailure = AppError(
  code: 'messages_failed',
  userMessage: 'Could not load message threads',
);

/// Hand-rolled gateway stub: queue of results (like the vault/matter
/// stubs), or a Completer for in-flight tests.
class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway({List<Result<List<MessageThread>>>? results})
    : _queue = results == null
          ? <Result<List<MessageThread>>>[
              Result<List<MessageThread>>.success(_threads),
            ]
          : List<Result<List<MessageThread>>>.of(results),
      completer = null;

  _StubMessageGateway.withCompleter()
    : _queue = const <Result<List<MessageThread>>>[],
      completer = Completer<Result<List<MessageThread>>>();

  final List<Result<List<MessageThread>>> _queue;
  final Completer<Result<List<MessageThread>>>? completer;
  int fetchCalls = 0;

  @override
  Future<Result<List<MessageThread>>> fetchThreads() {
    fetchCalls += 1;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<List<MessageThread>>>.value(_queue.removeAt(0));
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    // Not exercised by the thread-list cubit tests; an honest empty success
    // keeps the seam implementable for the detail cubit tests.
    return const Result<List<Message>>.success(<Message>[]);
  }
}
