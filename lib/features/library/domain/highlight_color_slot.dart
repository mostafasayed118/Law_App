/// The four highlight colour slots (ADR-0010).
///
/// A closed set, mirroring the `legal_highlight_color` enum in migration 33. The
/// reader maps each slot to a theme token pair (light and dark); the enum exists
/// so a new colour needs a design decision and a token, not a migration.
enum HighlightColorSlot { yellow, green, blue, pink }

/// Wire name, matching the Postgres enum value exactly.
String highlightColorWire(HighlightColorSlot slot) => slot.name;

/// Parses a wire value; unknown values are drift and fail loudly.
HighlightColorSlot highlightColorFromWire(String value) {
  for (final HighlightColorSlot slot in HighlightColorSlot.values) {
    if (slot.name == value) {
      return slot;
    }
  }
  throw FormatException('Unknown highlight colour: $value');
}
