import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/research/supabase_research_api.dart';
import 'package:legalhub/data/row_reader.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';

/// Research gateway backed by the Supabase function + read RPCs (design §5).
///
/// The HTTP contract is the plan's exact shape: analysis invokes
/// `research-analyze` with ids and the question only; runs/findings come from
/// `list_research_runs` / `list_research_findings`. Typed
/// [SupabaseResearchException]s become [AppError]s with the wire code
/// preserved (`unauthorized`, `forbidden`, `invalid_request`,
/// `context_too_large`, `provider_not_configured`, `provider_unavailable`,
/// `invalid_response`) so presentation can render the honest state — in
/// particular, a missing provider secret is never a synthetic success.
///
/// Reads need the caller's active organization id, supplied as a resolver so
/// the data layer never imports the app-scoped store.
class SupabaseResearchGateway implements AiGateway {
  SupabaseResearchGateway(this._api, {required this.organizationId});

  final SupabaseResearchApi _api;
  final String? Function() organizationId;

  /// Legacy corpus-query entry point (the demo seam's shape). A configured
  /// build routes through the real analysis path with the active org and no
  /// cited documents, so callers never receive synthetic copy here.
  @override
  Future<Result<List<AiFinding>>> research(String query) async {
    final Result<ResearchOutcome> result = await analyze(
      ResearchRequest(organizationId: organizationId() ?? '', question: query),
    );
    return switch (result) {
      Success<ResearchOutcome>(value: final ResearchOutcome outcome) =>
        Result<List<AiFinding>>.success(outcome.findings),
      Failure<ResearchOutcome>(error: final AppError error) =>
        Result<List<AiFinding>>.failure(error),
    };
  }

  @override
  Future<Result<ResearchOutcome>> analyze(ResearchRequest request) async {
    if (!request.isValid) {
      return Result<ResearchOutcome>.failure(
        const AppError(
          code: 'invalid_request',
          userMessage:
              'Enter a question between 2 and 500 characters and select an organization.',
        ),
      );
    }
    try {
      final Map<String, dynamic> payload = await _api.analyze(
        organizationId: request.organizationId,
        matterId: request.matterId,
        documentIds: request.documentIds,
        question: request.question,
      );
      return Result<ResearchOutcome>.success(_outcomeFrom(payload));
    } on SupabaseResearchException catch (e) {
      return Result<ResearchOutcome>.failure(_errorFor(e, read: false));
    } on FormatException catch (e) {
      return Result<ResearchOutcome>.failure(_drift(e, read: false));
    }
  }

  @override
  Future<Result<List<ResearchRun>>> fetchRuns({int limit = 20}) async {
    if (limit <= 0) {
      return const Result<List<ResearchRun>>.success(<ResearchRun>[]);
    }
    final String? organizationId = this.organizationId();
    if (organizationId == null || organizationId.isEmpty) {
      return Result<List<ResearchRun>>.failure(
        const AppError(
          code: 'invalid_request',
          userMessage: 'Select an organization to view research runs.',
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listRuns(
        organizationId: organizationId,
        limit: limit,
      );
      return Result<List<ResearchRun>>.success(
        List<ResearchRun>.unmodifiable(rows.map(_runFrom)),
      );
    } on SupabaseResearchException catch (e) {
      return Result<List<ResearchRun>>.failure(_errorFor(e, read: true));
    } on FormatException catch (e) {
      return Result<List<ResearchRun>>.failure(_drift(e, read: true));
    }
  }

  @override
  Future<Result<List<AiFinding>>> fetchFindings(String runId) async {
    final String id = runId.trim();
    if (id.isEmpty) {
      return Result<List<AiFinding>>.failure(
        const AppError(
          code: 'invalid_request',
          userMessage: 'Select a research run to view its findings.',
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listFindings(id);
      return Result<List<AiFinding>>.success(
        List<AiFinding>.unmodifiable(rows.map(_storedFindingFrom)),
      );
    } on SupabaseResearchException catch (e) {
      return Result<List<AiFinding>>.failure(_errorFor(e, read: true));
    } on FormatException catch (e) {
      return Result<List<AiFinding>>.failure(_drift(e, read: true));
    }
  }

  /// Maps the 200 body to an outcome. A completed contract carries 1..12
  /// findings; an empty or out-of-range list is provider drift.
  ResearchOutcome _outcomeFrom(Map<String, dynamic> payload) {
    final String runId = requiredString(payload, 'run_id');
    final ResearchRunStatus status = _statusOf(payload['status']);
    final Object? raw = payload['findings'];
    if (raw is! List<dynamic>) {
      throw const FormatException('Research response has no findings list');
    }
    if (raw.isEmpty || raw.length > 12) {
      throw const FormatException(
        'Research response must carry between 1 and 12 findings',
      );
    }
    final List<AiFinding> findings = <AiFinding>[];
    for (int index = 0; index < raw.length; index++) {
      final Object? row = raw[index];
      if (row is! Map) {
        throw const FormatException(
          'Research response has a malformed finding',
        );
      }
      final Map<String, dynamic> findingRow;
      try {
        findingRow = Map<String, dynamic>.from(row);
      } on Object {
        // Deliberately `on Object`: Map.from raises TypeError (an Error) on
        // a malformed key/value shape, and that drift must stay the typed
        // FormatException.
        throw const FormatException(
          'Research response has a malformed finding',
        );
      }
      findings.add(_findingFrom(findingRow, runId: runId, index: index));
    }
    return ResearchOutcome(
      runId: runId,
      status: status,
      model: optionalString(payload['model']),
      findings: List<AiFinding>.unmodifiable(findings),
    );
  }

  AiFinding _findingFrom(
    Map<String, dynamic> row, {
    required String runId,
    required int index,
  }) {
    final AiSourceKind kind = _sourceKindOf(row['source_type']);
    final String? sourceId = optionalString(row['source_id']);
    if (kind != AiSourceKind.none && sourceId == null) {
      throw const FormatException(
        'Research finding cites a source but carries no source id',
      );
    }
    return AiFinding(
      id: '$runId-$index',
      headline: requiredString(row, 'headline'),
      summary: requiredString(row, 'summary'),
      excerpt: optionalString(row['excerpt']) ?? '',
      sources: <AiSource>[
        AiSource(
          kind: kind,
          title: '',
          detail: '',
          sourceId: kind == AiSourceKind.none ? null : sourceId,
        ),
      ],
    );
  }

  /// One persisted `research_findings` row.
  AiFinding _storedFindingFrom(Map<String, dynamic> row) {
    final AiSourceKind kind = _sourceKindOf(row['source_type']);
    return AiFinding(
      id: requiredString(row, 'id'),
      headline: requiredString(row, 'headline'),
      summary: requiredString(row, 'summary'),
      excerpt: optionalString(row['excerpt']) ?? '',
      sources: <AiSource>[
        AiSource(
          kind: kind,
          title: '',
          detail: '',
          sourceId: kind == AiSourceKind.none
              ? null
              : optionalString(row['source_id']),
        ),
      ],
    );
  }

  /// One persisted `research_runs` row.
  ResearchRun _runFrom(Map<String, dynamic> row) {
    return ResearchRun(
      id: requiredString(row, 'id'),
      organizationId: requiredString(row, 'organization_id'),
      matterId: optionalString(row['matter_id']),
      status: _statusOf(row['status']),
      model: optionalString(row['model']),
      promptSummary: requiredString(row, 'prompt_summary'),
      errorCode: optionalString(row['error_code']),
      createdAt: requiredDate(row, 'created_at'),
      completedAt: optionalDate(row['completed_at']),
    );
  }

  ResearchRunStatus _statusOf(Object? value) => switch (value) {
    'running' => ResearchRunStatus.running,
    'completed' => ResearchRunStatus.completed,
    'failed' => ResearchRunStatus.failed,
    _ => throw const FormatException('Research row has an unknown status'),
  };

  AiSourceKind _sourceKindOf(Object? value) => switch (value) {
    'document' => AiSourceKind.document,
    'matter' => AiSourceKind.matter,
    'none' => AiSourceKind.none,
    _ => throw const FormatException('Research finding has an unknown source'),
  };

  /// Maps a seam failure to a redaction-safe [AppError]. The question and
  /// document bodies never cross into errors; only the provider's own message
  /// crosses as the technical message.
  AppError _errorFor(SupabaseResearchException e, {required bool read}) {
    return switch (e.kind) {
      SupabaseResearchFailureKind.unauthorized => AppError(
        code: 'unauthorized',
        userMessage: read
            ? 'Sign in again to view research history.'
            : 'Sign in again to use AI research.',
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.forbidden => AppError(
        code: 'forbidden',
        userMessage: read
            ? 'You do not have permission to view research history.'
            : 'Your role cannot run AI research.',
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.invalidRequest => AppError(
        code: 'invalid_request',
        userMessage: read
            ? 'Unable to load research history. Please try again.'
            : 'Check the question and selected items, then try again.',
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.contextTooLarge => AppError(
        code: 'context_too_large',
        userMessage:
            'The selected context is too large. Remove documents and try again.',
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.providerNotConfigured => AppError(
        code: 'provider_not_configured',
        userMessage:
            'AI research is not configured for this deployment. No analysis was run.',
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.providerUnavailable => AppError(
        code: 'provider_unavailable',
        userMessage: read
            ? 'Research history is temporarily unavailable. Please try again.'
            : 'The AI provider is temporarily unavailable. Please try again.',
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.invalidResponse => AppError(
        code: 'invalid_response',
        userMessage:
            'The AI provider returned an unexpected response. Please try again.',
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.notFound => AppError(
        code: 'invalid_request',
        userMessage: 'The selected research run was not found.',
        technicalMessage: e.message,
      ),
      SupabaseResearchFailureKind.unknown => AppError(
        code: 'research_failed',
        userMessage: 'Unable to run AI research. Please try again.',
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row shape) surfaces loudly, never as a
  /// silently wrong finding or run.
  AppError _drift(FormatException e, {required bool read}) => AppError(
    code: 'invalid_response',
    userMessage: read
        ? 'Unable to read the research history. Please try again.'
        : 'The AI provider returned an unexpected response. Please try again.',
    technicalMessage: e.message,
  );
}
