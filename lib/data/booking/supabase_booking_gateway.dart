import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/booking/domain/booking_category.dart';
import 'package:legalhub/features/booking/domain/booking_confirmation.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';
import 'package:legalhub/features/booking/domain/booking_slot.dart';
import 'supabase_booking_api.dart';

/// [BookingGateway] backed by the Supabase provider via [SupabaseBookingApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseTaskGateway]): raw slot rows become [BookingSlot] VOs, the VO's
/// [BookingCategory] maps to the server enum, free text is trimmed at the
/// boundary, and typed [SupabaseBookingException]s become [AppError]s.
///
/// Privacy: the free-text topic, the attorney reference, and the returned
/// confirmation reference never enter a technical message. Provider technical
/// messages are fixed server wording; mapping drift carries a static message.
class SupabaseBookingGateway implements BookingGateway {
  SupabaseBookingGateway(this._api);

  final SupabaseBookingApi _api;

  /// The real backend path: the wizard must NOT render the local-only demo
  /// note when this gateway is registered.
  @override
  bool get isLocalOnly => false;

  @override
  Future<Result<List<BookingSlot>>> fetchSlots() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchSlots();
      return Result<List<BookingSlot>>.success(
        List<BookingSlot>.unmodifiable(rows.map(_slotFromRow)),
      );
    } on SupabaseBookingException catch (e) {
      return Result<List<BookingSlot>>.failure(_slotsFailureFor(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected id/timestamp/duration shape) surfaces
      // loudly, never as a silently wrong slot.
      return Result<List<BookingSlot>>.failure(
        AppError(
          code: 'booking_slots_failed',
          userMessage: 'Unable to load available times. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  @override
  Future<Result<BookingConfirmation>> confirm(BookingRequest request) async {
    final BookingSlot? slot = request.slot;
    if (slot == null) {
      // The cubit guards this; a slotless request is a programming error,
      // not a user-facing path.
      return Result<BookingConfirmation>.failure(
        const AppError(
          code: 'booking_confirm_failed',
          userMessage: 'Unable to confirm. Please try again.',
        ),
      );
    }
    try {
      final Map<String, dynamic> row = await _api.bookConsultation(
        slotId: slot.id,
        category: _serverCategoryFor(request.category),
        topic: _trimmedOrNull(request.topic),
        // Defense in depth (design §2 principle 2): even if a caller builds
        // the request directly, a non-UUID attorney reference never reaches
        // the RPC.
        attorneyRef: normalizeAttorneyRef(request.attorneyId),
      );
      return Result<BookingConfirmation>.success(_confirmationFromRow(row));
    } on SupabaseBookingException catch (e) {
      return Result<BookingConfirmation>.failure(_confirmFailureFor(e));
    } on FormatException catch (e) {
      return Result<BookingConfirmation>.failure(
        AppError(
          code: 'booking_confirm_failed',
          userMessage: 'Unable to confirm. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw slot row to the [BookingSlot] VO.
  ///
  /// The timestamp is parsed and converted to local time for display;
  /// malformed shape is provider drift and fails loudly.
  BookingSlot _slotFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Slot row has no id');
    }
    final Object? startsAt = row['starts_at'];
    if (startsAt is! String || startsAt.isEmpty) {
      throw const FormatException('Slot row has no starts_at');
    }
    final Object? duration = row['duration_minutes'];
    if (duration is! int) {
      throw const FormatException('Slot row has no duration_minutes');
    }
    return BookingSlot(
      id: id,
      startsAt: _parseStartsAt(startsAt),
      durationMinutes: duration,
    );
  }

  DateTime _parseStartsAt(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } on FormatException {
      // Never echo the raw value into the message.
      throw const FormatException('Slot row has an invalid starts_at');
    }
  }

  /// Maps the returned booking row to the confirmation.
  ///
  /// The RPC projection always carries a server-generated `reference_id`;
  /// its absence is provider drift and fails loudly.
  BookingConfirmation _confirmationFromRow(Map<String, dynamic> row) {
    final Object? referenceId = row['reference_id'];
    if (referenceId is! String || referenceId.isEmpty) {
      throw const FormatException('Consultation row has no reference_id');
    }
    return BookingConfirmation(referenceId: referenceId);
  }

  /// Maps the VO's [BookingCategory] to the server enum value.
  String _serverCategoryFor(BookingCategory category) {
    return switch (category) {
      BookingCategory.general => 'general',
      BookingCategory.followUp => 'follow_up',
      BookingCategory.urgent => 'urgent',
    };
  }

  /// Trims at the gateway boundary; blank becomes null (the RPC's own
  /// nullif(trim(...)) is the server-side backstop).
  String? _trimmedOrNull(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Maps a slot-read failure to a redaction-safe [AppError].
  ///
  /// The typed [AppErrorKind] is preserved so presentation renders the right
  /// state: denials are not retryable, outages are.
  AppError _slotsFailureFor(SupabaseBookingException e) {
    return switch (e.kind) {
      SupabaseBookingFailureKind.denied => AppError(
        code: 'booking_slots_denied',
        userMessage: 'You do not have permission to view available times.',
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseBookingFailureKind.providerUnavailable => AppError(
        code: 'booking_slots_unavailable',
        userMessage:
            'Available times are temporarily unavailable. Please try again.',
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      // validation/slotUnavailable cannot occur on the slot read; treating
      // them as the generic failure keeps the mapping total.
      SupabaseBookingFailureKind.validation ||
      SupabaseBookingFailureKind.slotUnavailable ||
      SupabaseBookingFailureKind.unknown => AppError(
        code: 'booking_slots_failed',
        userMessage: 'Unable to load available times. Please try again.',
        technicalMessage: e.message,
      ),
    };
  }

  /// Maps a booking-write failure to a redaction-safe [AppError].
  ///
  /// A lost slot race is the one typed conflict the wizard acts on; every
  /// other failure keeps the generic confirm copy while preserving the
  /// retry semantics through [AppError.kind].
  AppError _confirmFailureFor(SupabaseBookingException e) {
    return switch (e.kind) {
      SupabaseBookingFailureKind.slotUnavailable => AppError(
        code: 'booking_slot_unavailable',
        userMessage: 'That time is no longer available. Choose another time.',
        technicalMessage: e.message,
      ),
      SupabaseBookingFailureKind.denied => AppError(
        code: 'booking_confirm_failed',
        userMessage: 'You do not have permission to book this consultation.',
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseBookingFailureKind.validation => AppError(
        code: 'booking_confirm_failed',
        userMessage:
            'The booking details are invalid. Check them and try again.',
        technicalMessage: e.message,
      ),
      SupabaseBookingFailureKind.providerUnavailable => AppError(
        code: 'booking_confirm_failed',
        userMessage: 'Booking is temporarily unavailable. Please try again.',
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseBookingFailureKind.unknown => AppError(
        code: 'booking_confirm_failed',
        userMessage: 'Unable to confirm. Please try again.',
        technicalMessage: e.message,
      ),
    };
  }
}
