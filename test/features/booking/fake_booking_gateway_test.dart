import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/booking/data/fake_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_category.dart';
import 'package:legalhub/features/booking/domain/booking_confirmation.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';

void main() {
  group('FakeBookingGateway.fetchSlots', () {
    test('returns the fixed synthetic slot list, deterministic per call', () async {
      final FakeBookingGateway gateway = FakeBookingGateway();

      final List<Object?>? first = (await gateway.fetchSlots()).valueOrNull;
      final List<Object?>? second = (await gateway.fetchSlots()).valueOrNull;

      // Same values on every call — R3 determinism, no wall-clock dependence.
      expect(first, FakeBookingGateway.syntheticSlots);
      expect(second, first);
      expect(first, hasLength(3));
    });
  });

  group('FakeBookingGateway.confirm', () {
    test('persists in-memory and returns sequential synthetic reference ids',
        () async {
      final FakeBookingGateway gateway = FakeBookingGateway();

      final BookingConfirmation first = (await gateway.confirm(_draft())).valueOrNull!;
      final BookingConfirmation second =
          (await gateway.confirm(_draft())).valueOrNull!;

      expect(first.referenceId, 'LH-DEMO-0001');
      expect(second.referenceId, 'LH-DEMO-0002');
      expect(gateway.confirmedBookings, hasLength(2));
      expect(gateway.confirmedBookings.first, first);
      expect(gateway.confirmedBookings.last, second);
    });

    test('never persists request content — only the confirmation is stored',
        () async {
      final FakeBookingGateway gateway = FakeBookingGateway();

      await gateway.confirm(
        const BookingRequest(
          category: BookingCategory.urgent,
          topic: 'Sensitive matter details',
        ),
      );

      // The in-memory store exposes only the synthetic confirmation; the
      // free-text topic never leaves the request object (honesty boundary).
      final List<BookingConfirmation> stored = gateway.confirmedBookings;
      expect(stored, hasLength(1));
      expect(stored.single.referenceId, 'LH-DEMO-0001');
      expect(
        stored.toString(),
        isNot(contains('Sensitive matter details')),
      );
    });
  });
}

BookingRequest _draft() => const BookingRequest(
  category: BookingCategory.general,
);
