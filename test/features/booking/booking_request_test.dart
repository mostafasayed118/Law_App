import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/features/booking/domain/booking_category.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';
import 'package:legalhub/features/booking/domain/booking_slot.dart';

void main() {
  group('BookingRequest redaction (F1)', () {
    test('toString returns [REDACTED] and never contains the topic', () {
      const BookingRequest request = BookingRequest(
        category: BookingCategory.urgent,
        topic: 'My matter against Company X, contact jane@example.com',
      );

      expect(request.toString(), '[REDACTED]');
      expect(request.toString(), isNot(contains('Company X')));
      expect(request.toString(), isNot(contains('jane@example.com')));
    });

    test('toRedactedMap keeps structural fields but scrubs embedded PII', () {
      const BookingRequest request = BookingRequest(
        category: BookingCategory.general,
        topic: 'Call me at jane@example.com about the will',
      );

      final Map<String, Object?> map = request.toRedactedMap();

      // Structural fields pass through (mirroring SignUpRequest.toRedactedMap,
      // which only masks keyed-sensitive values and scrubbed strings).
      expect(map['category'], 'general');
      expect(map['slotId'], isNull);

      // The free-text topic's embedded email is scrubbed by Redactor.map.
      expect(map['topic'], isNot(contains('jane@example.com')));
      expect(map['topic'], contains('[REDACTED_EMAIL]'));
    });

    test(
      'toRedactedMap is idempotent under Redactor.map (privacy contract)',
      () {
        const BookingRequest request = BookingRequest(
          category: BookingCategory.followUp,
          topic: 'jane@example.com',
        );

        // Redactor.map is documented idempotent; re-running on the redacted map
        // must not resurrect or alter the scrubbed value.
        final Map<String, Object?> once = request.toRedactedMap();
        final Map<String, Object?> twice = Redactor.map(once);

        expect(twice, once);
      },
    );
  });

  group('BookingCategory (G2 pin)', () {
    test('exposes exactly the three approved values', () {
      // Owner decision D2: General / Follow-up / Urgent are the ONLY values.
      // This pin fails loudly if a legal-domain or consultation-mode category
      // is ever added without an explicit owner decision.
      expect(BookingCategory.values, <BookingCategory>[
        BookingCategory.general,
        BookingCategory.followUp,
        BookingCategory.urgent,
      ]);
      expect(BookingCategory.values.length, 3);
    });
  });

  group('BookingRequest value semantics', () {
    test('equates on category, topic, and slot (Equatable props)', () {
      final DateTime startsAt = DateTime(2026, 8, 10, 10);
      final BookingRequest first = BookingRequest(
        category: BookingCategory.general,
        topic: 'estate matter',
        slot: BookingSlot(
          id: 'slot-1',
          startsAt: startsAt,
          durationMinutes: 30,
        ),
      );
      final BookingRequest second = BookingRequest(
        category: BookingCategory.general,
        topic: 'estate matter',
        slot: BookingSlot(
          id: 'slot-1',
          startsAt: startsAt,
          durationMinutes: 30,
        ),
      );

      expect(second, first);
      expect(BookingRequest(category: BookingCategory.urgent), isNot(first));
    });
  });
}
