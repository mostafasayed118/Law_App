/// Serializes the video Join action (audit 2026-10-27, F16).
///
/// A second tap while the room-token request is still in flight is a no-op
/// instead of a second progress dialog and a second call screen. The gate is
/// owned by the screen's state and released when the join settles — success,
/// failure, or a thrown call.
class JoinGate {
  bool _inFlight = false;

  /// True when the caller may start a join; false when one is in flight.
  bool tryBegin() {
    if (_inFlight) {
      return false;
    }
    _inFlight = true;
    return true;
  }

  /// Releases the gate. Idempotent: a stray end cannot corrupt the next join.
  void end() {
    _inFlight = false;
  }
}
