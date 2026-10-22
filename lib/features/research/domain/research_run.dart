import 'package:equatable/equatable.dart';

/// Lifecycle of one persisted research run (design §5).
///
/// Mirrors the `research_runs.status` check constraint. A failed run is
/// still persisted with its [ResearchRun.errorCode], so history never hides
/// an honest failure behind an empty list.
enum ResearchRunStatus { running, completed, failed }

/// One `research_runs` row (design §5; plan 2026-10-22, Task 6).
///
/// [promptSummary] is the caller's question as persisted by the server; it is
/// already bounded to 2..500 characters by the table check.
class ResearchRun extends Equatable {
  const ResearchRun({
    required this.id,
    required this.organizationId,
    required this.status,
    required this.promptSummary,
    required this.createdAt,
    this.matterId,
    this.model,
    this.errorCode,
    this.completedAt,
  });

  final String id;
  final String organizationId;
  final String? matterId;
  final ResearchRunStatus status;
  final String? model;
  final String promptSummary;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? completedAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    organizationId,
    matterId,
    status,
    model,
    promptSummary,
    errorCode,
    createdAt,
    completedAt,
  ];
}
