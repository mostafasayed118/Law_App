import '../../../core/errors/result.dart';
import 'ai_finding.dart';
import 'research_outcome.dart';
import 'research_request.dart';
import 'research_run.dart';

/// AI research integration boundary (AI research slice, plan 2026-09-02;
/// real-provider extension, design §5 / plan 2026-10-22 Task 6).
///
/// Two postures share this seam:
/// - the **env-less demo** registers [SyntheticAiGateway] — deterministic
///   findings over the shipped document/matter seams, clearly labelled in the
///   UI and never selected by a configured build;
/// - a **configured build** registers `SupabaseResearchGateway`, which calls
///   the `research-analyze` Edge Function and reads persisted runs/findings
///   through the audited RPCs. The provider key never reaches the client.
///
/// Return convention matches the project's `Result` boundary — failures
/// arrive as `Failure` with a typed `AppError`, never raw exceptions.
abstract interface class AiGateway {
  /// Researches the synthetic corpus for [query] and returns the
  /// deterministic findings list (demo posture only). An empty result is an
  /// honest outcome (no fabricated rows); upstream read failures map to
  /// typed failures.
  Future<Result<List<AiFinding>>> research(String query);

  /// Runs one user-triggered analysis through the configured provider
  /// (design §5). The function reads the cited rows under the caller's JWT,
  /// so ids are the only context sent. A missing provider secret surfaces as
  /// a `provider_not_configured` failure — never a synthetic result.
  Future<Result<ResearchOutcome>> analyze(ResearchRequest request);

  /// The active organization's runs, newest first, capped at [limit].
  Future<Result<List<ResearchRun>>> fetchRuns({int limit = 20});

  /// The persisted findings of [runId], ordered by `sort_order`.
  Future<Result<List<AiFinding>>> fetchFindings(String runId);
}
