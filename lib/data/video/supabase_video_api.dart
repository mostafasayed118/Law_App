/// Provider-neutral video RPC/function seam (design §6; plan Task 6).
///
/// The seam is the only surface the video gateway talks to: plain map
/// payloads out, typed [SupabaseVideoException]s on failure. Provider types
/// never cross this boundary (the research/compliance api-interface pattern).
library;

/// Typed failure classes from the five video RPCs and the `video-token`
/// contract. The function's `{ "error": "<code>" }` body is preserved in
/// [SupabaseVideoException.code] so the gateway can map the exact wire code
/// before falling back to the HTTP status.
enum SupabaseVideoFailureKind {
  /// No valid session / 401.
  unauthorized,

  /// The caller lacks membership, role, or creator rights / 403 or an RPC
  /// denial.
  forbidden,

  /// The requested session is not visible to the caller.
  notFound,

  /// The session already ended or was cancelled (409 on `video-token`).
  sessionEnded,

  /// `LIVEKIT_*` secrets are absent — an honest unavailable state / 409.
  providerNotConfigured,

  /// An RPC rejected the request (bad status transition or input).
  validation,

  /// The provider or transport was unreachable (retryable).
  unavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseVideoApi] seam.
class SupabaseVideoException implements Exception {
  const SupabaseVideoException({
    required this.kind,
    required this.message,
    this.code,
  });

  final SupabaseVideoFailureKind kind;
  final String message;

  /// The function's wire `error` code, when the failure came from its JSON
  /// body (`unauthorized`, `forbidden`, `session_not_found`, …).
  final String? code;

  @override
  String toString() =>
      'SupabaseVideoException(${kind.name}, code: $code): $message';
}

/// The video surface backed by the five RPCs and the `video-token` function.
abstract interface class SupabaseVideoApi {
  /// `list_video_sessions(p_organization_id)` — org-scoped, newest first.
  Future<List<Map<String, dynamic>>> listSessions({
    required String organizationId,
  });

  /// `create_video_session(p_organization_id, p_matter_id, p_booking_id,
  /// p_scheduled_at)` — returns the new session id.
  Future<String> createSession({
    required String organizationId,
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  });

  /// `POST /functions/v1/video-token` with `{ "session_id": "<uuid>" }`;
  /// returns the decoded `{ url, token, room }` body.
  Future<Map<String, dynamic>> fetchToken(String sessionId);

  /// `mark_video_session_live(p_id)`.
  Future<void> markLive(String id);

  /// `end_video_session(p_id)`.
  Future<void> end(String id);
}
