import '../../../core/errors/result.dart';
import 'ai_finding.dart';

/// AI research integration boundary (AI research slice, plan 2026-09-02).
///
/// Mirrors the credential-free discipline of every shipped gateway seam:
/// the demo posture (ratified scope decision D-1 —
/// `docs/ai_scope_decision_2026-08-11.md`) has **no model provider**; the
/// registered implementation is the deterministic `SyntheticAiGateway`. An
/// env-gated real provider, if ever approved, arrives behind this same seam
/// — nothing above it may know or care.
///
/// Boundary discipline (ratified A-3/C-1/D-3):
/// - the corpus is the **shipped gateway seams only** (D-2) — documents and
///   matters rows; no AI-only corpus table exists;
/// - **no persistence anywhere** — prompts and outputs are session-only;
/// - **no write path** — findings are advisory-only (C-4).
///
/// Return convention matches the project's [Result] boundary — failures
/// arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class AiGateway {
  /// Researches the synthetic corpus for [query] and returns the
  /// deterministic findings list. An empty result is an honest outcome
  /// (no fabricated rows); upstream read failures map to typed failures.
  Future<Result<List<AiFinding>>> research(String query);
}
