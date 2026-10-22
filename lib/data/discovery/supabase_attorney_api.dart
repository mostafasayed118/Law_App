/// Provider-neutral attorney-directory RPC seam (design §2).
///
/// The seam is the only surface the attorney gateway talks to: plain map rows
/// out, typed [SupabaseAttorneyException]s on failure. Provider types never
/// cross this boundary (same discipline as `SupabaseMatterApi`).
library;

/// Typed reasons a directory read or write can fail, mapped from PostgREST.
///
/// Reads go through `list_attorney_profiles` / `get_attorney_profile`, writes
/// through the four owner-only audited RPCs. Any of them can raise the stable
/// `permission denied` text; the not-found and validation arms come from the
/// RPCs' explicit `raise exception` / `check_violation` gates.
enum SupabaseAttorneyFailureKind {
  /// The caller is not permitted (non-owner write, no active membership, or
  /// no session / no EXECUTE grant).
  denied,

  /// The requested profile does not exist (or is inactive for this caller).
  notFound,

  /// A write the server refused as invalid (missing/short display name,
  /// out-of-range years, malformed row).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseAttorneyApi] seam.
class SupabaseAttorneyException implements Exception {
  const SupabaseAttorneyException({required this.kind, required this.message});

  final SupabaseAttorneyFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseAttorneyException(${kind.name}): $message';
}

/// The attorney-directory surface backed by the Supabase PostgREST client.
///
/// The list read is the server-side query RPC (`list_attorney_profiles`); the
/// admin listing sets `p_include_inactive`, which the RPC gates to the
/// platform owner. Every write is one of the audited owner-only RPCs — there
/// is no INSERT/UPDATE/DELETE grant on `attorney_profiles`.
abstract interface class SupabaseAttorneyApi {
  /// Directory rows matching [query]; active-only unless [includeInactive]
  /// (owner-only, enforced in-function), capped at [limit] (1–100).
  Future<List<Map<String, dynamic>>> listAttorneys({
    String query = '',
    bool includeInactive = false,
    int limit = 50,
  });

  /// One profile by id. Throws a `notFound` exception when the RPC returns
  /// no row (the RPC raises the same text for a hidden inactive row).
  Future<Map<String, dynamic>> getAttorney(String id);

  /// Creates a profile through `create_attorney_profile`; returns the new id.
  Future<String> createAttorney({
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  });

  /// Replaces the editable fields of [id] through
  /// `update_attorney_profile`.
  Future<void> updateAttorney(
    String id, {
    required String displayName,
    required List<String> specialties,
    required List<String> languages,
    String? headline,
    String? bio,
    String? city,
    int? yearsExperience,
    String? avatarUrl,
  });

  /// Marks [id] inactive through `deactivate_attorney_profile`.
  Future<void> deactivateAttorney(String id);
}
