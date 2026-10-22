import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/ai_finding.dart';
import '../domain/ai_gateway.dart';
import '../domain/research_outcome.dart';
import '../domain/research_request.dart';
import '../domain/research_run.dart';
import 'ai_research_state.dart';

/// Owns the research surface (AI research slice 1.1; design §5).
///
/// [generate] submits a [ResearchRequest] through the [AiGateway] seam and
/// renders the typed lifecycle; [loadRuns] reads the persisted history and
/// [loadRunFindings] opens one stored run. The legacy [research] entry point
/// stays for the env-less demo path (the synthetic gateway's corpus query).
/// Widgets dispatch intents and render [AiResearchState]; they never call the
/// gateway directly.
class AiResearchCubit extends Cubit<AiResearchState> {
  AiResearchCubit(this._gateway) : super(const AiResearchState());

  final AiGateway _gateway;

  /// In-flight guard — the [NotificationCubit] pattern: the flag, not a
  /// state check, distinguishes "request in flight" from "idle", and
  /// duplicate submits while a request is running are ignored.
  bool _loading = false;

  /// Monotonic history request id: a refresh while a read is in flight must
  /// not be overwritten by the older response (the SearchCubit pattern).
  int _runsRequest = 0;

  /// Reads the organization's run history. A failure lands on the history
  /// arm only — it never replaces a displayed answer.
  Future<void> loadRuns() async {
    final int request = ++_runsRequest;
    if (state.runs is! ViewLoading<List<ResearchRun>>) {
      emit(state.copyWith(runs: const ViewLoading<List<ResearchRun>>()));
    }
    final Result<List<ResearchRun>> result = await _gateway.fetchRuns();
    if (isClosed || request != _runsRequest) {
      return;
    }
    switch (result) {
      case Success<List<ResearchRun>>(value: final List<ResearchRun> runs):
        emit(
          state.copyWith(
            runs: runs.isEmpty
                ? const ViewEmpty<List<ResearchRun>>()
                : ViewSuccess<List<ResearchRun>>(runs),
          ),
        );
      case Failure<List<ResearchRun>>(error: final AppError error):
        emit(
          state.copyWith(runs: viewStateForFailure<List<ResearchRun>>(error)),
        );
    }
  }

  /// Runs one real analysis. An invalid request is rejected locally with the
  /// same typed code the function uses, so a configured build never sends an
  /// out-of-contract body. A successful or failed run refreshes the history
  /// (a failed run is persisted with its error code by the function).
  Future<void> generate(ResearchRequest request) async {
    if (isClosed || _loading) {
      return;
    }
    if (!request.isValid) {
      const AppError error = AppError(
        code: 'invalid_request',
        userMessage:
            'Enter a question between 2 and 500 characters and select an organization.',
      );
      emit(
        state.copyWith(
          findings: const ViewError<List<AiFinding>>(error),
          lastQuery: request.question,
          lastError: error,
        ),
      );
      return;
    }
    _loading = true;
    emit(
      state.copyWith(
        findings: const ViewLoading<List<AiFinding>>(),
        lastQuery: request.question,
        lastError: null,
      ),
    );
    final Result<ResearchOutcome> result = await _gateway.analyze(request);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<ResearchOutcome>(value: final ResearchOutcome outcome):
        emit(
          state.copyWith(
            findings: outcome.findings.isEmpty
                ? const ViewSuccess<List<AiFinding>>(<AiFinding>[])
                : ViewSuccess<List<AiFinding>>(outcome.findings),
            lastError: null,
          ),
        );
      case Failure<ResearchOutcome>(error: final AppError error):
        emit(
          state.copyWith(
            findings: error.code == 'provider_not_configured'
                ? const ViewEmpty<List<AiFinding>>()
                : viewStateForFailure<List<AiFinding>>(error),
            lastError: error,
          ),
        );
    }
    await loadRuns();
  }

  /// Opens one stored run's findings. The history row's prompt summary becomes
  /// the answer's query label, so an empty stored result reads as "no
  /// findings for this run" rather than the idle prompt.
  Future<void> loadRunFindings(String runId) async {
    if (isClosed || _loading) {
      return;
    }
    String label = '';
    if (state.runs case ViewSuccess<List<ResearchRun>>(
      data: final List<ResearchRun> runs,
    )) {
      for (final ResearchRun run in runs) {
        if (run.id == runId) {
          label = run.promptSummary;
          break;
        }
      }
    }
    _loading = true;
    emit(
      state.copyWith(
        findings: const ViewLoading<List<AiFinding>>(),
        lastQuery: label,
        lastError: null,
      ),
    );
    final Result<List<AiFinding>> result = await _gateway.fetchFindings(runId);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<AiFinding>>(value: final List<AiFinding> findings):
        emit(state.copyWith(findings: ViewSuccess<List<AiFinding>>(findings)));
      case Failure<List<AiFinding>>(error: final AppError error):
        emit(
          state.copyWith(
            findings: viewStateForFailure<List<AiFinding>>(error),
            lastError: error,
          ),
        );
    }
  }

  /// The env-less demo corpus query (AI research slice 1.1, D-R2). Kept
  /// separate from [generate] because it carries no organization, matter, or
  /// document context; the synthetic gateway is the only implementation that
  /// answers it meaningfully.
  Future<void> research(String rawQuery) async {
    final String query = rawQuery.trim();
    if (isClosed || _loading || query.isEmpty) {
      return;
    }
    _loading = true;
    emit(
      state.copyWith(
        findings: const ViewLoading<List<AiFinding>>(),
        lastQuery: query,
        lastError: null,
      ),
    );
    final Result<List<AiFinding>> result = await _gateway.research(query);
    _loading = false;
    if (isClosed) {
      return;
    }
    switch (result) {
      case Success<List<AiFinding>>(value: final List<AiFinding> findings):
        emit(
          state.copyWith(
            findings: ViewSuccess<List<AiFinding>>(findings),
            lastError: null,
          ),
        );
      case Failure<List<AiFinding>>(error: final AppError error):
        emit(
          state.copyWith(
            findings: viewStateForFailure<List<AiFinding>>(error),
            lastError: error,
          ),
        );
    }
  }
}
