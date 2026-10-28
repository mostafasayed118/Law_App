/// Provider-neutral matter-write seam (F-01 step 2 client swap).
///
/// The seam is the only surface the write gateway talks to: the audited
/// `create_matter` RPC call in, the persisted matter id (uuid) out, typed
/// [SupabaseMatterWriteException]s on failure. Provider types never cross
/// this boundary (the `SupabaseMessageApi` discipline) — the injected RPC
/// callable type lives in the impl file, which is the only file that touches
/// provider types.
library;

/// Typed reasons the `create_matter` call can fail, mapped 1:1 from the
/// RPC's in-function refusals (docs/f01_step2_matter_write_design_2026-08-09.md
/// F2-D1/F2-D2/F2-D4 — the C-D2 client error kinds).
enum SupabaseMatterWriteFailureKind {
  /// The caller is not an active partner of the org, or is outside it
  /// (F2-D1 — the RPC's `permission denied`), or RLS denied at the privilege
  /// layer.
  denied,

  /// The platform-owner id was passed as an assignee (F2-D2 — the F-01 core
  /// refusal; the categorical trigger would refuse it on any path).
  ownerForbidden,

  /// An assignee is not an active member of the org (F2-D4 — the
  /// dead-assignment guard).
  assigneeInvalid,

  /// The title is blank (the RPC's `matter title is required`) or the
  /// practice_area fails the 04 CHECK (mapping contract).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseMatterWriteApi] seam.
class SupabaseMatterWriteException implements Exception {
  const SupabaseMatterWriteException({
    required this.kind,
    required this.message,
  });

  final SupabaseMatterWriteFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseMatterWriteException(${kind.name}): $message';
}

/// The audited matter-creation surface backed by the Supabase PostgREST
/// client.
///
/// Calls `create_matter(uuid, text, text, uuid, uuid)` — the ONLY matter
/// write path (the direct-INSERT grant is revoked and the categorical
/// `refuse_platform_owner_assignment` trigger backs every path, F2-D3). The
/// server is the authority: org membership (F2-D1), the platform-owner
/// refusal (F2-D2), and the active-member assignee guard (F2-D4) are all
/// re-derived in-function; the client sends only the create intent (D-08).
/// §8 audit is server-side only — the client never writes audit rows.
abstract interface class SupabaseMatterWriteApi {
  /// Creates one matter through the audited RPC and returns the persisted
  /// matter id (uuid).
  ///
  /// Parameters mirror the RPC's EXACT names: `p_organization_id`,
  /// `p_title`, `p_practice_area`, `p_assigned_client_id`,
  /// `p_assigned_attorney_id`. The practice area is the `PracticeArea`
  /// enum-name (the 04 CHECK contract). Assignees are optional (F2-D5 —
  /// orphan creates allowed).
  Future<String> createMatter({
    required String organizationId,
    required String title,
    required String practiceArea,
    String? assignedClientId,
    String? assignedAttorneyId,
  });
}
