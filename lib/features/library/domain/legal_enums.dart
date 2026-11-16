/// Enumerations for the Legal Library (ADR-0009).
///
/// Pure domain values with no wire format and no Flutter import: the Supabase
/// adapter owns the snake_case mapping (`court_ruling`, `in_force`) so a
/// database rename cannot leak into the UI, and a drift value fails mapping
/// loudly at the adapter rather than surfacing as a silently wrong label.
library;

/// What kind of instrument a source publishes.
enum LegalSourceKind { statute, regulation, courtRuling }

/// The browse taxonomy. Deliberately coarse: eight buckets a reader can scan,
/// not the full classification a legal database would need.
enum LegalCategory {
  civil,
  criminal,
  labor,
  commercial,
  family,
  administrative,
  constitutional,
  other,
}

/// The lifecycle state of a document as published, not as interpreted. The
/// library never asserts that a text is currently in force; it reports what the
/// imported metadata says, and `unknown` is the honest default.
enum LegalStatus { inForce, amended, repealed, unknown }
