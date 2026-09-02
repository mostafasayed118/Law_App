import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../domain/ai_finding.dart';

/// Immutable state of the AI research surface (AI research slice 1.1,
/// plan 2026-09-02).
///
/// [findings] holds the **latest submitted query's** lifecycle using the
/// shared [ViewState] vocabulary (loading / success / empty / error+retry).
/// The state is `idle` until the first submit; only the latest query's
/// result is ever held (D-R2 — last answer only, no transcript), and the
/// cubit is feature-scoped so nothing survives leaving the screen (C-1 —
/// no persistence).
class AiResearchState extends Equatable {
  const AiResearchState({
    this.findings = const ViewSuccess<List<AiFinding>>(<AiFinding>[]),
    this.lastQuery = '',
  });

  /// The latest query's finding-list lifecycle. **Idle-by-success**: an
  /// empty success means "no query submitted yet" or "the last query
  /// matched nothing" — the screen distinguishes the two via [lastQuery].
  final ViewState<List<AiFinding>> findings;

  /// The trimmed query the current [findings] answers. Empty until the
  /// first submit; used by the screen to render the idle prompt vs the
  /// honest no-match empty state.
  final String lastQuery;

  AiResearchState copyWith({
    ViewState<List<AiFinding>>? findings,
    String? lastQuery,
  }) {
    return AiResearchState(
      findings: findings ?? this.findings,
      lastQuery: lastQuery ?? this.lastQuery,
    );
  }

  @override
  List<Object?> get props => <Object?>[findings, lastQuery];
}
