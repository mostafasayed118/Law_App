import '../../../core/errors/result.dart';
import '../domain/message.dart';
import '../domain/message_gateway.dart';
import '../domain/message_thread.dart';

/// Development-only messaging implementation: a fixed synthetic list of
/// non-PII message-thread **metadata**.
///
/// No real backend, no storage, no realtime, no message bodies, no send/reply
/// (owner decisions D-MSG1/D-MSG2/D-MSG4/D-MSG6): [fetchThreads] returns the
/// same deterministic list on every call. Threads carry id / generic demo
/// title / matter reference / participants / last-activity date / message
/// count only — **no body, no preview, no attachments, no client or
/// real-looking case references (D-MSG4)**, and titles are static demo copy
/// that must never read as a real case communication (R1 — the heaviest
/// fake-data honesty rail of any phase). The list resolves immediately (no
/// artificial delay) so cubit/widget tests stay timing-independent.
class FakeMessageGateway implements MessageGateway {
  /// The fixed synthetic thread-metadata list served by [fetchThreads].
  static final List<MessageThread> syntheticThreads = <MessageThread>[
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
    MessageThread(
      id: 'thread-3',
      title: 'Demo procedural notes',
      matterRef: 'Procedural review matter',
      participants: const <String>['Layla Mansour'],
      lastActivityAt: DateTime.utc(2026, 7, 22),
      messageCount: 5,
    ),
    MessageThread(
      id: 'thread-4',
      title: 'Family matter thread — demo',
      matterRef: 'Family status consultation',
      participants: const <String>['Omar Farouk', 'Demo client'],
      lastActivityAt: DateTime.utc(2026, 7, 19),
      messageCount: 15,
    ),
    MessageThread(
      id: 'thread-5',
      title: 'Startup advisory — demo',
      matterRef: 'Startup formation advisory',
      participants: const <String>['Sara Khalil', 'Demo client'],
      lastActivityAt: DateTime.utc(2026, 7, 15),
      messageCount: 9,
    ),
  ];

  /// Fixed synthetic per-thread message rows (D-RT5): each thread gets
  /// exactly its `messageCount` generic messages, authors alternating
  /// between the neutral `Demo attorney` / `Demo client`, bodies the generic
  /// demo pattern, and `sentAt` staggered by whole hours back from a fixed
  /// base — deterministic on every call (the fake's determinism pin).
  static final Map<String, List<Message>> syntheticMessagesByThread =
      <String, List<Message>>{
        for (final MessageThread thread in syntheticThreads)
          thread.id: _messagesFor(thread),
      };

  /// Builds the deterministic message list for one thread.
  static List<Message> _messagesFor(MessageThread thread) {
    return List<Message>.unmodifiable(
      List<Message>.generate(thread.messageCount, (int i) {
        final int n = i + 1;
        return Message(
          id: '${thread.id}-msg-$n',
          authorDisplayName: n.isOdd ? 'Demo attorney' : 'Demo client',
          body:
              'Demo message $n — generic demo content, no real client or '
              'legal data.',
          sentAt: thread.lastActivityAt.subtract(Duration(hours: n)),
        );
      }),
    );
  }

  @override
  Future<Result<List<MessageThread>>> fetchThreads() async {
    // Thread metadata only — the synthetic list is returned as-is; nothing
    // crosses this boundary but the D-MSG4 metadata surface.
    return Result<List<MessageThread>>.success(syntheticThreads);
  }

  @override
  Future<Result<List<Message>>> fetchMessages(String threadId) async {
    // Read-path surface (D-RT5): deterministic per-thread generic rows; an
    // unknown thread id is an honest empty success (the real RLS-scoped
    // SELECT returns zero rows for an unassigned/unknown thread).
    return Result<List<Message>>.success(
      syntheticMessagesByThread[threadId] ?? const <Message>[],
    );
  }
}
