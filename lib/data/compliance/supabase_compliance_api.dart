/// Provider-neutral compliance-alert RPC seam (design §4).
///
/// The seam is the only surface the compliance gateway talks to: plain map
/// rows out, typed [SupabaseComplianceException]s on failure. Provider types
/// never cross this boundary (same discipline as `SupabaseApprovalApi`).
library;

/// Typed reasons a compliance read or write can fail, mapped from PostgREST.
///
/// Reads go through `list_compliance_alerts`; writes through the three
/// audited RPCs. They raise the stable `permission denied` text, while the
/// not-found and terminal-state arms come from the RPCs' explicit
/// `raise exception` gates.
enum SupabaseComplianceFailureKind {
  /// The caller is not permitted (RLS denial, in-function gate, or no
  /// session / no EXECUTE grant).
  denied,

  /// The alert does not exist (or is not visible to this caller).
  notFound,

  /// A write the server refused as invalid (title bounds, note bounds,
  /// terminal transition).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseComplianceApi] seam.
class SupabaseComplianceException implements Exception {
  const SupabaseComplianceException({
    required this.kind,
    required this.message,
  });

  final SupabaseComplianceFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseComplianceException(${kind.name}): $message';
}

/// The compliance-alert surface backed by the Supabase PostgREST client.
abstract interface class SupabaseComplianceApi {
  /// The organization's `compliance_alerts` rows, newest first. [status] and
  /// [severity] are server enum values (`open|acknowledged|resolved`,
  /// `low|medium|high|critical`); null returns every value.
  Future<List<Map<String, dynamic>>> listAlerts({
    required String organizationId,
    String? status,
    String? severity,
  });

  /// Creates an alert through `create_compliance_alert`; returns the new id.
  Future<String> createAlert({
    required String organizationId,
    String? matterId,
    required String kind,
    required String severity,
    required String title,
    String? description,
    DateTime? dueAt,
  });

  /// Acknowledges an open alert through `acknowledge_compliance_alert`.
  Future<void> acknowledgeAlert(String id);

  /// Resolves an alert through `resolve_compliance_alert`.
  Future<void> resolveAlert(String id, {String? note});
}
