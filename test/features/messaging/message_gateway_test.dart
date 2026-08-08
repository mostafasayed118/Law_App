import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
import 'package:legalhub/features/messaging/domain/message.dart';
import 'package:legalhub/features/messaging/domain/message_realtime_event.dart';
import 'package:legalhub/features/messaging/domain/message_thread.dart';

void main() {
  group('FakeMessageGateway.fetchThreads (AC-1)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeMessageGateway gateway = FakeMessageGateway();

      final List<MessageThread>? first =
          (await gateway.fetchThreads()).valueOrNull;
      final List<MessageThread>? second =
          (await gateway.fetchThreads()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeMessageGateway.syntheticThreads);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('threads carry only non-PII metadata fields (D-MSG4 shape)', () async {
      final FakeMessageGateway gateway = FakeMessageGateway();

      final List<MessageThread> threads =
          (await gateway.fetchThreads()).valueOrNull!;

      // Every synthetic thread exposes the D-MSG4 surface: id / generic demo
      // title / matter reference / participants / last-activity date /
      // message count. Metadata only — the string forms must never render
      // contact or client-identity shapes (no email/phone/address), and a
      // thread with zero messages would read as a broken row.
      for (final MessageThread thread in threads) {
        expect(thread.id, isNotEmpty);
        expect(thread.title, isNotEmpty);
        expect(thread.matterRef, isNotEmpty);
        expect(thread.participants, isNotEmpty);
        expect(thread.messageCount, greaterThan(0));
        expect(thread.toString(), isNot(contains('@')));
      }
    });

    test(
      'thread copy carries explicit demo framing (R1 — heaviest rail)',
      () async {
        final FakeMessageGateway gateway = FakeMessageGateway();

        final List<MessageThread> threads =
            (await gateway.fetchThreads()).valueOrNull!;

        // R1 pin (matter_messaging_scope_2026-08-03.md §6 R1): thread titles
        // must never read as real case communications — every title carries
        // explicit demo framing, every matter reference is one of the known
        // synthetic matter titles, and no participant renders a contact shape.
        const Set<String> knownMatterTitles = <String>{
          'Demo acquisition review',
          'Commercial lease consultation',
          'Procedural review matter',
          'Family status consultation',
          'Startup formation advisory',
        };
        for (final MessageThread thread in threads) {
          expect(
            thread.title.toLowerCase(),
            contains('demo'),
            reason: 'thread ${thread.id} title lacks demo framing',
          );
          expect(
            knownMatterTitles,
            contains(thread.matterRef),
            reason: 'thread ${thread.id} references an unknown matter',
          );
          for (final String participant in thread.participants) {
            expect(participant, isNot(contains('@')));
          }
        }
      },
    );
  });

  group('FakeMessageGateway.fetchMessages (D-RT5)', () {
    test(
      'returns deterministic per-thread rows matching each messageCount',
      () async {
        final FakeMessageGateway gateway = FakeMessageGateway();

        for (final MessageThread thread
            in FakeMessageGateway.syntheticThreads) {
          final List<Message> first = (await gateway.fetchMessages(
            thread.id,
          )).valueOrNull!;
          final List<Message> second = (await gateway.fetchMessages(
            thread.id,
          )).valueOrNull!;

          // Same values on every call — no wall-clock or random dependence.
          expect(first, second);
          expect(first, hasLength(thread.messageCount));
          // Every row belongs to the requested thread (id prefix contract).
          expect(first.first.id, startsWith('${thread.id}-msg-'));
        }
      },
    );

    test('rows are read-path generic demo copy, never real communications '
        '(R1/D-RT4)', () async {
      final FakeMessageGateway gateway = FakeMessageGateway();

      for (final MessageThread thread in FakeMessageGateway.syntheticThreads) {
        for (final Message message in (await gateway.fetchMessages(
          thread.id,
        )).valueOrNull!) {
          expect(message.authorDisplayName, isNotEmpty);
          expect(message.body.toLowerCase(), contains('demo'));
          expect(message.body, isNot(contains('@')));
          expect(message.toString(), isNot(contains('@')));
        }
      }
    });

    test('an unknown thread id is an honest empty success', () async {
      final FakeMessageGateway gateway = FakeMessageGateway();

      final List<Message> messages = (await gateway.fetchMessages(
        'thread-unknown',
      )).valueOrNull!;

      expect(messages, isEmpty);
    });
  });

  group('FakeMessageGateway.sendMessage (D-LV1)', () {
    test(
      'appends a deterministic row the fetchMessages read reflects',
      () async {
        final FakeMessageGateway gateway = FakeMessageGateway();
        final String threadId = FakeMessageGateway.syntheticThreads.first.id;
        final int before = (await gateway.fetchMessages(
          threadId,
        )).valueOrNull!.length;

        final Message? sent = (await gateway.sendMessage(
          threadId,
          'A demo send',
          authorDisplayName: 'Demo Partner',
        )).valueOrNull;
        final List<Message> after = (await gateway.fetchMessages(
          threadId,
        )).valueOrNull!;

        expect(sent, isNotNull);
        expect(sent!.id, '$threadId-sent-1');
        expect(sent.authorDisplayName, 'Demo Partner');
        expect(sent.body, 'A demo send');
        // Fixed timestamp — no wall-clock dependence (the determinism pin).
        expect(sent.sentAt, DateTime.utc(2026, 8, 8));
        expect(after, hasLength(before + 1));
        expect(after.last.id, sent.id);
      },
    );

    test(
      'falls back to a neutral generic author when none is given (D-RT4)',
      () async {
        final FakeMessageGateway gateway = FakeMessageGateway();

        final Message? sent = (await gateway.sendMessage(
          'thread-1',
          'Body',
        )).valueOrNull;

        expect(sent!.authorDisplayName, 'Demo client');
      },
    );

    test('sent state is instance-scoped, never shared across fakes', () async {
      final FakeMessageGateway a = FakeMessageGateway();
      final FakeMessageGateway b = FakeMessageGateway();
      final String threadId = FakeMessageGateway.syntheticThreads.first.id;

      await a.sendMessage(threadId, 'From A');
      final List<Message> bMessages = (await b.fetchMessages(
        threadId,
      )).valueOrNull!;

      expect(bMessages.any((Message m) => m.body == 'From A'), isFalse);
    });
  });

  group('FakeMessageGateway.watchMessages (D-LV4)', () {
    test(
      'is a never-emitting stream (no live delivery in env-less runs)',
      () async {
        final FakeMessageGateway gateway = FakeMessageGateway();

        final List<MessageRealtimeEvent> events = <MessageRealtimeEvent>[];
        await for (final MessageRealtimeEvent event in gateway.watchMessages(
          'thread-1',
        )) {
          events.add(event);
        }

        expect(events, isEmpty);
      },
    );
  });
}
