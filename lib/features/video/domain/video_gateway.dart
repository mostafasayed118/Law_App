import '../../../core/errors/result.dart';
import 'video_session.dart';
import 'video_token.dart';

/// Video-consultation integration boundary (design §6).
///
/// Reads and writes go through audited, RPC-only server paths; the media
/// token comes from the `video-token` Edge Function under the caller's JWT.
/// No provider secret crosses this boundary and no synthetic call is ever
/// produced: a deployment without LiveKit secrets fails with the typed
/// `provider_not_configured` error, which the UI renders as an honest
/// unavailable state.
///
/// Return convention matches the project's [Result] boundary — failures
/// arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class VideoGateway {
  /// The active organization's sessions (newest first), scoped by RLS.
  Future<Result<List<VideoSession>>> fetchSessions();

  /// Creates a scheduled session. [matterId] and [bookingId] are optional
  /// references; the create RPC re-asserts the partner/attorney gate, the
  /// same-org matter rule, and the caller's read access to that matter.
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  });

  /// Fetches the room URL + JWT for [sessionId] from `video-token`.
  Future<Result<VideoToken>> fetchToken(String sessionId);

  /// Marks a scheduled session live (idempotent server gate: scheduled only).
  Future<Result<void>> markLive(String id);

  /// Ends a session. Only its creator or a partner may end it.
  Future<Result<void>> end(String id);
}
