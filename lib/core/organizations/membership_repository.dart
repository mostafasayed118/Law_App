import '../auth/session.dart';

/// Membership hydration boundary (P3.2).
///
/// Populates [Session.memberships] from the RLS-scoped `memberships` /
/// `organizations` SELECT surface (own rows + org names). The domain
/// boundary returns application [OrganizationMembership]s — never raw
/// Supabase DTOs, tokens, or provider exceptions (contract §5). The server
/// remains the authority: roles/statuses arrive as-is, and unknown schema
/// roles are never projected as capabilities (D-T5 / D-P32.1).
///
/// Hydration is a **best-effort enrichment** of an already-authenticated
/// session (plan §6): the session itself is never invalidated by a
/// hydration problem. The typed [MembershipHydrationResult] lets the cubit
/// seam distinguish "the provider reported no memberships" (honest empty —
/// `HydrationSucceeded([])`) from "hydration could not complete"
/// (`HydrationFailed` — surfaced through the diagnostic channel; Task 8
/// review input 1).
abstract interface class MembershipRepository {
  /// Loads the caller's organization memberships (RLS-scoped).
  ///
  /// [userId] is the caller's stable id; the provider derives the query
  /// scope from the authenticated session, so [userId] is a contract-§5
  /// identity hint, not a filter that widens access.
  Future<MembershipHydrationResult> loadMemberships({required String userId});
}

/// Outcome of a membership-hydration attempt (P3.2 Task 8).
///
/// Sealed so the presentation seam must handle both arms explicitly: a
/// reported-but-empty membership list stays the honest `[]`, while a failed
/// read still authenticates the session but is surfaced for diagnostics and
/// retry decisions.
sealed class MembershipHydrationResult {
  const MembershipHydrationResult._();
}

/// The provider reported the caller's memberships — possibly none.
final class HydrationSucceeded extends MembershipHydrationResult {
  const HydrationSucceeded(this.memberships) : super._();

  final List<OrganizationMembership> memberships;
}

/// Hydration could not complete; the session is not invalidated.
final class HydrationFailed extends MembershipHydrationResult {
  const HydrationFailed(this.kind) : super._();

  final MembershipHydrationFailureKind kind;
}

/// Typed reasons hydration can fail, mapped from the provider seam.
enum MembershipHydrationFailureKind {
  /// The caller is not permitted to read the memberships surface.
  denied,

  /// The provider/configuration is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}
