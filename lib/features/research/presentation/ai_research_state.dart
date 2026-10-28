import 'package:equatable/equatable.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/research_run.dart';

/// Immutable state of the research surface (AI research slice 1.1; design §5).
///
/// [findings] holds the current answer lifecycle using the shared [ViewState]
/// vocabulary. [runs] holds the persisted history (last 20). [matters] and
/// [documents] hold the optional pickers' lookup lifecycles — they are
/// optional context, so each fails independently and never gates generation.
/// [lastError] preserves the typed wire code even when the findings arm is a
/// terminal state (denial / unavailable), so presentation can render the exact
/// honest copy — especially `provider_not_configured`, which renders an
/// explicit unavailable state rather than a retry that cannot succeed.
class AiResearchState extends Equatable {
  const AiResearchState({
    this.findings = const ViewSuccess<List<AiFinding>>(<AiFinding>[]),
    this.runs = const ViewSuccess<List<ResearchRun>>(<ResearchRun>[]),
    this.matters = const ViewSuccess<List<Matter>>(<Matter>[]),
    this.documents = const ViewSuccess<List<Document>>(<Document>[]),
    this.lastQuery = '',
    this.lastError,
  });

  /// The current answer lifecycle. **Idle-by-success**: an empty success means
  /// "no query submitted yet" or "the last request produced no findings" —
  /// the screen distinguishes the two via [lastQuery] and [lastError].
  final ViewState<List<AiFinding>> findings;

  /// The organization's persisted runs, newest first (server-capped at 20).
  final ViewState<List<ResearchRun>> runs;

  /// The optional matter picker's lookup lifecycle. An empty success means
  /// "no matters available" (or no lookup gateway wired), never "not loaded".
  final ViewState<List<Matter>> matters;

  /// The optional document picker's lookup lifecycle, same idle-by-success
  /// contract as [matters].
  final ViewState<List<Document>> documents;

  /// The trimmed question the current [findings] answer. Empty until the
  /// first request.
  final String lastQuery;

  /// The typed failure behind the current arm, when there is one.
  final AppError? lastError;

  AiResearchState copyWith({
    ViewState<List<AiFinding>>? findings,
    ViewState<List<ResearchRun>>? runs,
    ViewState<List<Matter>>? matters,
    ViewState<List<Document>>? documents,
    String? lastQuery,
    Object? lastError = _unset,
  }) {
    return AiResearchState(
      findings: findings ?? this.findings,
      runs: runs ?? this.runs,
      matters: matters ?? this.matters,
      documents: documents ?? this.documents,
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
    matters,
    documents,
    lastQuery,
    lastError,
  ];
}
