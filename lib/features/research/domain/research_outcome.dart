import 'package:equatable/equatable.dart';

import 'ai_finding.dart';
import 'research_run.dart';

/// The result of one `research-analyze` call (design §5).
///
/// [runId] is the persisted `research_runs` row; [findings] are the rows the
/// function wrote for it. The HTTP contract only returns a completed run, so
/// [status] is normally [ResearchRunStatus.completed] — a failed call arrives
/// as a typed [Failure] instead of an outcome.
class ResearchOutcome extends Equatable {
  const ResearchOutcome({
    required this.runId,
    required this.status,
    required this.findings,
    this.model,
  });

  final String runId;
  final ResearchRunStatus status;
  final String? model;
  final List<AiFinding> findings;

  @override
  List<Object?> get props => <Object?>[runId, status, model, findings];
}
