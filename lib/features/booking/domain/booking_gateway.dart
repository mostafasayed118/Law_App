import '../../../core/errors/result.dart';
import 'booking_confirmation.dart';
import 'booking_request.dart';
import 'booking_slot.dart';

/// Consultation booking integration boundary.
///
/// Mirrors the credential-free discipline of [SignUpGateway]: this slice
/// deliberately has no real backend. A fake/in-memory implementation is
/// registered for dev so the presentation layer can exercise the booking
/// lifecycle; no real booking data crosses this boundary yet, and the real
/// data contract (`BookingRequest` / `BookingSlot` shapes) is deferred to
/// P2/P3.
///
/// Return convention matches the project's [Result] boundary (§D.4) and
/// [SignUpGateway] exactly — failures arrive as [Failure] with [AppError],
/// never raw exceptions.
abstract interface class BookingGateway {
  /// The synthetic slot list for the date-time step. Deterministic and
  /// availability-free (owner decision D3).
  Future<Result<List<BookingSlot>>> fetchSlots();

  /// Persists the booking into the in-memory fake only; no backend promise
  /// is made and the wording of any UI around it must stay local-only
  /// (owner decision D4).
  Future<Result<BookingConfirmation>> confirm(BookingRequest request);
}
