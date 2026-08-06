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
/// session: a provider read failure resolves to the honest empty list (the
/// session itself is not invalidated), and the honest empty case is kept
/// when the provider reports no memberships (plan §6).
abstract interface class MembershipRepository {
  /// Loads the caller's organization memberships (RLS-scoped).
  ///
  /// [userId] is the caller's stable id; the provider derives the query
  /// scope from the authenticated session, so [userId] is a contract-§5
  /// identity hint, not a filter that widens access.
  Future<List<OrganizationMembership>> loadMemberships({
    required String userId,
  });
}
