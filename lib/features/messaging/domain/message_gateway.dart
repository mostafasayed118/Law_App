import '../../../core/errors/result.dart';
import 'message.dart';
import 'message_thread.dart';

/// Matter-scoped messaging integration boundary (Phase 9, slice 9.0;
/// sixth §14 un-deferral, realtime slice D-RT5).
///
/// The thread-metadata half mirrors the credential-free discipline of
/// [DocumentGateway] (Phase 8 D-V2): a fake/in-memory implementation is
/// registered for dev so the messaging surface can exercise the read-only
/// lifecycle, and the real data path was deferred per roadmap §13 until P0
/// closed + policy tests existed (owner decisions D-MSG2/D-MSG3) — that
/// gate is now met, so the env-gated Supabase implementation serves the
/// applied `message_threads` + `messages` tables (owner decisions D-MSR1/
/// D-MSR7/D-RT5).
///
/// **fetchMessages is the D-MSG1 consummation:** the `body` field — the
/// first content column in the public schema — crosses this boundary for
/// the first time, scoped to the **read path only** (no write grant, no
/// send/reply/composer in this slice; D-RT5).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class MessageGateway {
  /// The caller's assignment-scoped thread-metadata list (active member of
  /// the thread's org AND assigned on its matter, matrix §4 — the
  /// `message_threads_select_assigned` RLS gate server-side). Deterministic
  /// and read-only (owner decisions D-MSG1/D-MSG2/D-MSG4). **Thread
  /// metadata only — no message body crosses this boundary here.**
  Future<Result<List<MessageThread>>> fetchThreads();

  /// The caller's assignment-scoped message rows for one thread (the
  /// `messages_select_assigned` RLS gate — the thread gate extended one
  /// hop, D-RT2). Deterministic and read-only. **This is the read-path
  /// surface that carries message bodies** (D-MSG1 consummation, D-RT5).
  Future<Result<List<Message>>> fetchMessages(String threadId);
}
