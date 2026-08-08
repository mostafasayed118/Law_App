import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';
import 'package:legalhub/features/messaging/presentation/message_thread_detail_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpDetail(
    WidgetTester tester, {
    String threadId = 'thread-3',
    String? threadTitle,
    MessageGateway? gatewayOverride,
  }) async {
    // MessageThreadDetailScreen resolves MessageGateway from the locator
    // (the dev fake by default; a pre-registered stub wins when injected —
    // configureDependencies skips registered singletons).
    if (gatewayOverride != null) {
      serviceLocator.registerLazySingleton<MessageGateway>(
        () => gatewayOverride,
      );
    }
    configureDependencies();
    // A tall surface so the thread's message rows build inside the ListView.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MessageThreadDetailScreen(
          threadId: threadId,
          threadTitle: threadTitle,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('message thread detail surface (D-RT5)', () {
    testWidgets('renders the thread title and its message rows read-only', (
      tester,
    ) async {
      await pumpDetail(tester, threadTitle: 'Demo procedural notes');

      // The tapped row's title is the AppBar title (Q3 — passed client-side).
      expect(find.text('Demo procedural notes'), findsOneWidget);
      // thread-3 carries 5 deterministic generic rows: authors alternate
      // Demo attorney / Demo client, bodies are the generic demo pattern.
      expect(find.text('Demo attorney'), findsNWidgets(3));
      expect(find.text('Demo client'), findsNWidgets(2));
      expect(find.textContaining('generic demo content'), findsNWidgets(5));
      // Read-only: no composer, no send/reply affordance anywhere.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Send'), findsNothing);
    });

    testWidgets('falls back to the localized title when none is passed', (
      tester,
    ) async {
      await pumpDetail(tester, threadId: 'thread-3', threadTitle: null);

      expect(find.text('Thread messages'), findsOneWidget);
    });

    testWidgets('renders the empty state for a thread with no rows', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        threadId: 'thread-unknown',
        gatewayOverride: _StubMessageGateway(
          results: <Result<List<Message>>>[
            const Result<List<Message>>.success(<Message>[]),
          ],
        ),
      );

      expect(
        find.text('No messages are available in this thread.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the error state and retries', (tester) async {
      final _StubMessageGateway gateway = _StubMessageGateway(
        results: <Result<List<Message>>>[
          Result<List<Message>>.failure(_loadFailure),
          Result<List<Message>>.success(_singleMessage),
        ],
      );
      await pumpDetail(tester, gatewayOverride: gateway);

      expect(find.text('Unable to load messages.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load messages.'), findsNothing);
      expect(find.text('Demo attorney'), findsOneWidget);
      expect(gateway.fetchCalls, <String>['thread-3', 'thread-3']);
    });
  });
}

final List<Message> _singleMessage = <Message>[
  Message(
    id: 'thread-3-msg-1',
    authorDisplayName: 'Demo attorney',
    body:
        'Demo message 1 — generic demo content, no real client or legal '
        'data.',
    sentAt: DateTime.utc(2026, 7, 22),
  ),
];

final AppError _loadFailure = AppError(
  code: 'message_body_read_failed',
  userMessage: 'Unable to load messages.',
);

/// Hand-rolled gateway stub: queue of message results (the fake is the
/// default; this stub injects failures/empties for state tests).
class _StubMessageGateway implements MessageGateway {
  _StubMessageGateway({required List<Result<List<Message>>> results})
    : _queue = List<Result<List<Message>>>.of(results);

  final List<Result<List<Message>>> _queue;
  final List<String> fetchCalls = <String>[];

  @override
  Future<Result<List<MessageThread>>> fetchThreads() async =>
      const Result<List<MessageThread>>.success(<MessageThread>[]);

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) {
    fetchCalls.add(threadId);
    return Future<Result<List<Message>>>.value(_queue.removeAt(0));
  }
}
