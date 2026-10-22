/// Provider-neutral research RPC/function seam (design §5; plan Task 6).
///
/// The seam is the only surface the research gateway talks to: plain map
/// payloads out, typed [SupabaseResearchException]s on failure. Provider types
/// never cross this boundary (the `SupabaseApprovalApi` / `ComplianceApi`
/// discipline).
library;

/// Typed failure classes from the `research-analyze` contract and the three
/// read RPCs. The function's `{ "error": "<code>" }` body is preserved in
/// [SupabaseResearchException.code] so the gateway can map the exact wire
/// code before falling back to the HTTP status.
enum SupabaseResearchFailureKind {
  /// No valid session / 401.
  unauthorized,

  /// The caller's role is not attorney or partner / 403 or an RPC denial.
  forbidden,

  /// The question, ids, or read request failed validation / 400.
  invalidRequest,

  /// The composed context exceeded the function's 12k-character cap / 422.
  contextTooLarge,

  /// `RIVER_API_KEY` is absent — an honest unavailable state / 409.
  providerNotConfigured,

  /// River was unreachable or returned a transport failure / 502/503/504.
  providerUnavailable,

  /// River returned a payload that failed the structured-JSON check.
  invalidResponse,

  /// The requested run is not visible to the caller.
  notFound,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseResearchApi] seam.
class SupabaseResearchException implements Exception {
  const SupabaseResearchException({
    required this.kind,
    required this.message,
    this.code,
  });

  final SupabaseResearchFailureKind kind;
  final String message;

  /// The function's wire `error` code, when the failure came from its JSON
  /// body (`unauthorized`, `forbidden`, `invalid_request`, …).
  final String? code;

  @override
  String toString() =>
      'SupabaseResearchException(${kind.name}, code: $code): $message';
}

/// The research surface backed by the Supabase function and PostgREST client.
abstract interface class SupabaseResearchApi {
  /// Invokes `research-analyze` with the exact HTTP contract in the plan:
  /// `organization_id`, `matter_id`, `document_ids`, `question`.
  Future<Map<String, dynamic>> analyze({
    required String organizationId,
    String? matterId,
    required List<String> documentIds,
    required String question,
  });

  /// The organization's `research_runs` rows, newest first, capped at
  /// [limit] by the seam.
  Future<List<Map<String, dynamic>>> listRuns({
    required String organizationId,
    required int limit,
  });

  /// The persisted findings of [runId], ordered by `sort_order`.
  Future<List<Map<String, dynamic>>> listFindings(String runId);
}
