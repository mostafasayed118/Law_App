/// Provider-neutral approval-request RPC seam (design §3).
///
/// The seam is the only surface the approval gateway talks to: plain map rows
/// out, typed [SupabaseApprovalException]s on failure. Provider types never
/// cross this boundary (same discipline as `SupabaseAttorneyApi`).
library;

/// Typed reasons an approval read or write can fail, mapped from PostgREST.
///
/// Reads go through `list_approval_requests`; writes through the three audited
/// RPCs. They raise the stable `permission denied` text, while the not-found
/// and validation arms come from the RPCs' explicit `raise exception` /
/// `check_violation` gates.
enum SupabaseApprovalFailureKind {
  /// The caller is not permitted (RLS denial, in-function gate, or no
  /// session / no EXECUTE grant).
  denied,

  /// The request does not exist (or is not visible to this caller).
  notFound,

  /// A write the server refused as invalid (title length, rejection note,
  /// non-pending transition).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseApprovalApi] seam.
class SupabaseApprovalException implements Exception {
  const SupabaseApprovalException({required this.kind, required this.message});

  final SupabaseApprovalFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseApprovalException(${kind.name}): $message';
}

/// The approval-request surface backed by the Supabase PostgREST client.
abstract interface class SupabaseApprovalApi {
  /// The organization's `approval_requests` rows, newest first. [status] is
  /// the server enum value (`pending`, `approved`, `rejected`, `cancelled`);
  /// null returns every status.
  Future<List<Map<String, dynamic>>> listApprovals({
    required String organizationId,
    String? status,
  });

  /// Creates a request through `create_approval_request`; returns the new id.
  Future<String> createApproval({
    required String organizationId,
    String? matterId,
    required String title,
    required String kind,
    String? description,
  });

  /// Decides a pending request through `decide_approval_request`.
  /// [decision] is `approved` or `rejected`.
  Future<void> decideApproval(
    String id, {
    required String decision,
    String? note,
  });

  /// Cancels a pending request through `cancel_approval_request`.
  Future<void> cancelApproval(String id);
}
