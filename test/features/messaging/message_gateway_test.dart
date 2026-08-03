import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/messaging/data/fake_message_gateway.dart';
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
}
