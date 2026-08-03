import '../../../core/errors/result.dart';
import '../domain/booking_confirmation.dart';
import '../domain/booking_gateway.dart';
import '../domain/booking_request.dart';
import '../domain/booking_slot.dart';

/// Development-only booking implementation: fixed synthetic slots and an
/// in-memory confirmation list.
///
/// No real backend and no availability logic (owner decision D3): there are
/// no cutoffs, weekend rules, or attorney-schedule rules anywhere in this
/// class. [fetchSlots] returns the same deterministic list on every call.
/// [confirm] appends a synthetic confirmation to an in-memory list only —
/// nothing is sent, queued, or promised (D4). Both methods resolve
/// immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
///
/// R3: slot dates are fixed `DateTime` literals for test determinism; their
/// cosmetic staleness (they do not advance with the wall clock) is accepted
/// for a synthetic demo and must not grow into availability logic.
class FakeBookingGateway implements BookingGateway {
  /// The fixed synthetic slot list served by [fetchSlots].
  static final List<BookingSlot> syntheticSlots = <BookingSlot>[
    BookingSlot(
      id: 'slot-1',
      startsAt: DateTime(2026, 8, 10, 9, 0),
      durationMinutes: 30,
    ),
    BookingSlot(
      id: 'slot-2',
      startsAt: DateTime(2026, 8, 10, 11, 30),
      durationMinutes: 45,
    ),
    BookingSlot(
      id: 'slot-3',
      startsAt: DateTime(2026, 8, 11, 14, 0),
      durationMinutes: 60,
    ),
  ];

  final List<BookingConfirmation> _confirmed = <BookingConfirmation>[];
  int _nextReference = 1;

  /// Locally confirmed bookings, in-memory only. Read-only inspection seam
  /// for tests and future dev tooling; never a backend list.
  List<BookingConfirmation> get confirmedBookings =>
      List<BookingConfirmation>.unmodifiable(_confirmed);

  @override
  Future<Result<List<BookingSlot>>> fetchSlots() async {
    return Result<List<BookingSlot>>.success(
      List<BookingSlot>.unmodifiable(syntheticSlots),
    );
  }

  @override
  Future<Result<BookingConfirmation>> confirm(BookingRequest request) async {
    final BookingConfirmation confirmation = BookingConfirmation(
      referenceId: 'LH-DEMO-${_nextReference.toString().padLeft(4, '0')}',
    );
    _nextReference += 1;
    _confirmed.add(confirmation);
    return Result<BookingConfirmation>.success(confirmation);
  }
}
