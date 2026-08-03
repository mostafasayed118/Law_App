import '../../../core/errors/result.dart';
import 'message_thread.dart';

/// Matter-scoped messaging integration boundary (Phase 9, slice 9.0).
///
/// Mirrors the credential-free discipline of [DocumentGateway] (Phase 8
/// D-V2): this slice deliberately has no real backend. A fake/in-memory
/// implementation is registered for dev so the messaging surface can
/// exercise the read-only lifecycle; no real message data crosses this
/// boundary yet, and the real data path (table, RLS, storage, realtime)
/// stays deferred per roadmap §13 until P0 closes + policy tests exist
/// (owner decision D-MSG2/D-MSG3).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class MessageGateway {
  /// The synthetic thread-metadata list for the messaging surface.
  /// Deterministic and read-only (owner decisions D-MSG1/D-MSG2/D-MSG4).
  /// **No message body ever crosses this boundary.**
  Future<Result<List<MessageThread>>> fetchThreads();
}
