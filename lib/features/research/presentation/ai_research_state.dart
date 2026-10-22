import 'package:equatable/equatable.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/state/view_state.dart';
import '../domain/ai_finding.dart';
import '../domain/research_run.dart';

/// Immutable state of the research surface (AI research slice 1.1; design §5).
///
/// [findings] holds the current answer lifecycle using the shared [ViewState]
/// vocabulary. [runs] holds the persisted history (last 20). [lastError]
/// preserves the typed wire code even when the findings arm is a terminal
/// state (denial / unavailable), so presentation can render the exact honest
/// copy — especially `provider_not_configured`, which renders an explicit
/// unavailable state rather than a retry that cannot succeed.
class AiResearchState extends Equatable {
  const AiResearchState({
    this.findings = const ViewSuccess<List<AiFinding>>(<AiFinding>[]),
    this.runs = const ViewSuccess<List<ResearchRun>>(<ResearchRun>[]),
    this.lastQuery = '',
    this.lastError,
  });

  /// The current answer lifecycle. **Idle-by-success**: an empty success means
  /// "no query submitted yet" or "the last request produced no findings" —
  /// the screen distinguishes the two via [lastQuery] and [lastError].
  final ViewState<List<AiFinding>> findings;

  /// The organization's persisted runs, newest first (server-capped at 20).
  final ViewState<List<ResearchRun>> runs;

  /// The trimmed question the current [findings] answer. Empty until the
  /// first request.
  final String lastQuery;

  /// The typed failure behind the current arm, when there is one.
  final AppError? lastError;

  AiResearchState copyWith({
    ViewState<List<AiFinding>>? findings,
    ViewState<List<ResearchRun>>? runs,
    String? lastQuery,
    Object? lastError = _unset,
  }) {
    return AiResearchState(
      findings: findings ?? this.findings,
      runs: runs ?? this.runs,
      lastQuery: lastQuery ?? this.lastQuery,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as AppError?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => <Object?>[
    findings,
    runs,
    lastQuery,
    lastError,
  ];
}
