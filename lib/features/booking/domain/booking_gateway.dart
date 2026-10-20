import '../../../core/errors/result.dart';
import 'booking_confirmation.dart';
import 'booking_request.dart';
import 'booking_slot.dart';

/// Consultation booking integration boundary.
///
/// Two implementations share this contract: [FakeBookingGateway] for
/// env-less/dev runs and [SupabaseBookingGateway] for configured builds.
/// [isLocalOnly] is the honesty switch: presentation renders demo wording
/// only when the fake is registered, and the no-payment note on the real
/// path.
///
/// Return convention matches the project's [Result] boundary (§D.4) and
/// [SignUpGateway] exactly — failures arrive as [Failure] with [AppError],
/// never raw exceptions.
abstract interface class BookingGateway {
  /// Whether bookings are synthetic (in-memory fake) rather than persisted
  /// through the real backend. The wizard resolves this once at cubit
  /// creation and never claims a real booking in fake mode.
  bool get isLocalOnly;

  /// The slot list for the date-time step. The fake returns a deterministic
  /// synthetic list; the real path reads the RLS-scoped available-slot
  /// catalogue.
  Future<Result<List<BookingSlot>>> fetchSlots();

  /// Persists the booking. The fake appends to an in-memory list; the real
  /// path calls the audited `book_consultation` RPC.
  Future<Result<BookingConfirmation>> confirm(BookingRequest request);
}
