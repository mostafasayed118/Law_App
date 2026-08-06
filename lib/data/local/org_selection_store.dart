/// Persistence seam for the device-local active-organization selection
/// (P3.2, D-P32.2 — the ratified `ActiveOrgStore` persistence extension).
///
/// Mirrors the locale-store pattern (`lib/data/local/locale_store.dart`):
/// the production implementation writes to SharedPreferences, the in-memory
/// implementation backs tests and env-less runs. The selection is a
/// **client-side UX context only** (D-08) — it is never an authorization
/// claim, and every server request re-derives membership from the session.
abstract interface class OrgSelectionStore {
  /// Reads the last persisted active organization id, or null when none has
  /// been stored (or a stale/unknown value is found).
  Future<String?> read();

  /// Persists the selected active organization id.
  Future<void> write(String organizationId);
}
