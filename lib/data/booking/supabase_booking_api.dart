/// Provider-neutral consultation-booking seam.
///
/// The seam is the only surface the booking gateway talks to: plain map rows
/// out, typed [SupabaseBookingException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseTaskApi]).
library;

/// Typed reasons a slot read or booking write can fail, mapped from the
/// PostgREST surface.
///
/// `consultation_slots` is a plain RLS-scoped SELECT (available slots only);
/// the write is the audited `book_consultation` RPC, whose validation gates
/// raise `check_violation` (SQLSTATE `23514`), whose lost slot claim raises
/// `unique_violation` (SQLSTATE `23505`), and whose auth gate raises the
/// stable `permission denied` text.
enum SupabaseBookingFailureKind {
  /// The caller is not permitted to read slots or book a consultation
  /// (RLS denial, the in-function auth gate, or no EXECUTE grant).
  denied,

  /// The server refused the booking as invalid (category allow-list, topic
  /// length, attorney-reference length, null slot).
  validation,

  /// The slot was claimed by another booker between the catalogue read and
  /// the RPC call.
  slotUnavailable,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseBookingApi] seam.
class SupabaseBookingException implements Exception {
  const SupabaseBookingException({required this.kind, required this.message});

  final SupabaseBookingFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseBookingException(${kind.name}): $message';
}

/// Consultation booking surface backed by the Supabase PostgREST client.
///
/// The read is RLS-scoped (`consultation_slots_select_available`): only
/// active, unclaimed slots are visible. The write is the audited
/// `book_consultation` RPC — the only mutation path (no direct INSERT grant
/// or policy exists on either table). The RPC returns the persisted booking
/// as a non-PII jsonb row (no topic, no client id), so the gateway maps the
/// confirmation directly with no follow-up re-read.
abstract interface class SupabaseBookingApi {
  /// The available `consultation_slots` rows.
  ///
  /// Columns requested: `id`, `starts_at`, `duration_minutes` — the read
  /// surface the [BookingSlot] VO needs.
  Future<List<Map<String, dynamic>>> fetchSlots();

  /// Books a slot through the audited `book_consultation` RPC and returns
  /// the persisted non-PII row. [category] is the server enum value
  /// (`general`, `follow_up`, `urgent`); [topic] and [attorneyRef] are
  /// already trimmed by the caller (null when absent).
  Future<Map<String, dynamic>> bookConsultation({
    required String slotId,
    required String category,
    String? topic,
    String? attorneyRef,
  });
}
