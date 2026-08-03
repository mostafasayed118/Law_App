/// Transient, in-memory booking prefill set by the discovery profile surface
/// immediately before navigating to `/book` (Phase 6 D-A3 — the D-B7 additive
/// slice).
///
/// Holds only the two strings the booking flow needs (a stable synthetic
/// attorney id + its display name) — no `Attorney` import, so the booking
/// feature never depends on the discovery domain. App-scoped in the service
/// locator, never persisted or serialized, and **never travels in route
/// parameters or GoRouter `extra`** (D-B4): [BookingScreen] consumes it once
/// at cubit creation and calls [clear], so a later standalone `/book` visit
/// starts fresh (AC-5).
class BookingPrefill {
  String? attorneyId;
  String? attorneyName;

  /// Clears the prefill after the booking cubit has consumed it.
  void clear() {
    attorneyId = null;
    attorneyName = null;
  }
}
