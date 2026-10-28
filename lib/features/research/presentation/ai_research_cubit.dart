import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'ai_research_state.dart';

/// Owns the research surface (AI research slice 1.1; design §5).
///
/// [generate] submits a [ResearchRequest] through the [AiGateway] seam and
/// renders the typed lifecycle; [loadRuns] reads the persisted history and
/// [loadRunFindings] opens one stored run; [loadLookups] fills the optional
/// matter/document pickers. The legacy [research] entry point stays for the
/// env-less demo path (the synthetic gateway's corpus query). Widgets dispatch
/// intents and render [AiResearchState]; they never call a gateway directly.
class AiResearchCubit extends Cubit<AiResearchState> {
  AiResearchCubit(
    this._gateway, {
    MatterGateway? mattersGateway,
    DocumentGateway? documentsGateway,
  }) : _matters = mattersGateway,
       _documents = documentsGateway,
       super(const AiResearchState());

  final AiGateway _gateway;

  /// The optional picker seams. A null seam leaves its arm untouched — the
  /// lookups are optional context, not a requirement for generation.
  final MatterGateway? _matters;
  final DocumentGateway? _documents;

  /// In-flight guard — the [NotificationCubit] pattern: the flag, not a
  /// state check, distinguishes "request in flight" from "idle", and
  /// duplicate submits while a request is running are ignored.
  bool _loading = false;

  /// The lookup in-flight guard: a reload while the pair is loading is a
  /// no-op, so a double tap cannot interleave two settled pairs.
  bool _loadingLookups = false;

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

  /// Loads both optional pickers in parallel. Each arm settles on its own
  /// [ViewState]: a failed lookup renders inline with its own reload
  /// affordance and never blocks [generate] — the matter and documents are
  /// optional context. A missing seam keeps that arm at its current state.
  Future<void> loadLookups() async {
    if (isClosed || _loadingLookups) {
      return;
    }
    final MatterGateway? matterGateway = _matters;
    final DocumentGateway? documentGateway = _documents;
    if (matterGateway == null && documentGateway == null) {
      return;
    }
    _loadingLookups = true;
    emit(
      state.copyWith(
        matters: matterGateway == null
            ? state.matters
            : const ViewLoading<List<Matter>>(),
        documents: documentGateway == null
            ? state.documents
            : const ViewLoading<List<Document>>(),
      ),
    );
    // Both requests start before the first await, so the lookups run in
    // parallel (the record `.wait` is Future.wait for the two arms).
    final (Result<List<Matter>>?, Result<List<Document>>?) results;
    try {
      results = await (
        matterGateway?.fetchMatters() ?? Future<Result<List<Matter>>?>.value(),
        documentGateway?.fetchDocuments() ??
            Future<Result<List<Document>>?>.value(),
      ).wait;
    } finally {
      // Reset on throw too: a blown lookup must not wedge the reload guard.
      _loadingLookups = false;
    }
    if (isClosed) {
      return;
    }
    final Result<List<Matter>>? matterResult = results.$1;
    final Result<List<Document>>? documentResult = results.$2;
    emit(
      state.copyWith(
        matters: matterResult == null
            ? state.matters
            : _lookupState(matterResult),
        documents: documentResult == null
            ? state.documents
            : _lookupState(documentResult),
      ),
    );
  }

  ViewState<List<T>> _lookupState<T>(Result<List<T>> result) =>
      switch (result) {
        Success<List<T>>(value: final List<T> rows) => ViewSuccess<List<T>>(
          rows,
        ),
        Failure<List<T>>(error: final AppError error) =>
          viewStateForFailure<List<T>>(error),
      };

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
    final Result<ResearchOutcome> result;
    try {
      result = await _gateway.analyze(request);
    } finally {
      // Reset on throw too: a blown analysis must not wedge the submit guard.
      _loading = false;
    }
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
    final Result<List<AiFinding>> result;
    try {
      result = await _gateway.fetchFindings(runId);
    } finally {
      // Reset on throw too: a blown run read must not wedge the submit guard.
      _loading = false;
    }
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
    final Result<List<AiFinding>> result;
    try {
      result = await _gateway.research(query);
    } finally {
      // Reset on throw too: a blown query must not wedge the submit guard.
      _loading = false;
    }
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
