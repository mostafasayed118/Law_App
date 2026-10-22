import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/research/supabase_research_api_impl.dart';
import 'package:legalhub/data/research/supabase_research_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockFunctionCaller extends Mock {
  Future<Object?> call(String function, Map<String, dynamic> body);
}

class _MockRpcCaller extends Mock {
  Future<PostgrestResponse<dynamic>> call(
    String function,
    Map<String, dynamic> params,
  );
}

void main() {
  late _MockFunctionCaller functionCaller;
  late _MockRpcCaller rpcCaller;
  late SupabaseResearchGateway gateway;

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    functionCaller = _MockFunctionCaller();
    rpcCaller = _MockRpcCaller();
    gateway = SupabaseResearchGateway(
      SupabaseResearchApiImpl(
        functionCaller: functionCaller.call,
        rpcCaller: rpcCaller.call,
      ),
      organizationId: () => 'org-1',
    );
  });

  ResearchRequest request({String question = 'What changed?'}) {
    return ResearchRequest(
      organizationId: 'org-1',
      matterId: 'matter-1',
      documentIds: const <String>['doc-1'],
      question: question,
    );
  }

  group('SupabaseResearchGateway.analyze', () {
    test('sends the exact HTTP contract and maps findings', () async {
      when(() => functionCaller('research-analyze', any())).thenAnswer(
        (_) async => <String, dynamic>{
          'run_id': 'run-1',
          'status': 'completed',
          'model': 'deepseek-ai/DeepSeek-V4.1-Flash-1017',
          'findings': <Map<String, dynamic>>[
            <String, dynamic>{
              'headline': 'Headline one',
              'summary': 'Summary one.',
              'excerpt': 'Excerpt one.',
              'source_type': 'document',
              'source_id': 'doc-1',
            },
            <String, dynamic>{
              'headline': 'Headline two',
              'summary': 'Summary two.',
              'excerpt': null,
              'source_type': 'none',
              'source_id': null,
            },
          ],
        },
      );

      final Result<ResearchOutcome> result = await gateway.analyze(
        request(question: '  What changed?  '),
      );

      expect(result, isA<Success<ResearchOutcome>>());
      final ResearchOutcome outcome = result.valueOrNull!;
      expect(outcome.runId, 'run-1');
      expect(outcome.status, ResearchRunStatus.completed);
      expect(outcome.model, 'deepseek-ai/DeepSeek-V4.1-Flash-1017');
      expect(outcome.findings, hasLength(2));
      expect(
        outcome.findings.first.sources.single.kind,
        AiSourceKind.document,
      );
      expect(outcome.findings.first.sources.single.sourceId, 'doc-1');
      expect(outcome.findings.last.sources.single.kind, AiSourceKind.none);
      expect(outcome.findings.last.excerpt, isEmpty);

      final Map<String, dynamic> body =
          verify(
                () => functionCaller('research-analyze', captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'organization_id': 'org-1',
        'matter_id': 'matter-1',
        'document_ids': <String>['doc-1'],
        'question': 'What changed?',
      });
    });

    test('maps every wire error code to a typed AppError', () async {
      const List<(String, int, String, AppErrorKind)> cases =
          <(String, int, String, AppErrorKind)>[
            ('unauthorized', 401, 'unauthorized', AppErrorKind.denied),
            ('forbidden', 403, 'forbidden', AppErrorKind.denied),
            ('invalid_request', 400, 'invalid_request', AppErrorKind.unknown),
            ('context_too_large', 422, 'context_too_large', AppErrorKind.unknown),
            (
              'provider_not_configured',
              409,
              'provider_not_configured',
              AppErrorKind.unavailable,
            ),
            (
              'provider_unavailable',
              502,
              'provider_unavailable',
              AppErrorKind.unavailable,
            ),
            ('invalid_response', 500, 'invalid_response', AppErrorKind.unknown),
          ];
      for (final (
            String wire,
            int status,
            String expected,
            AppErrorKind kind,
          )
          in cases) {
        when(() => functionCaller('research-analyze', any())).thenThrow(
          FunctionException(status: status, details: <String, dynamic>{
            'error': wire,
          }),
        );
        final Result<ResearchOutcome> result = await gateway.analyze(request());
        expect(result, isA<Failure<ResearchOutcome>>(), reason: wire);
        expect(result.errorOrNull?.code, expected, reason: wire);
        expect(result.errorOrNull?.kind, kind, reason: wire);
      }
    });

    test('falls back to the HTTP status when the error body is stripped', () async {
      when(
        () => functionCaller('research-analyze', any()),
      ).thenThrow(const FunctionException(status: 409));

      final Result<ResearchOutcome> result = await gateway.analyze(request());

      expect(result.errorOrNull?.code, 'provider_not_configured');
      expect(result.errorOrNull?.kind, AppErrorKind.unavailable);
    });

    test('rejects malformed findings as invalid_response', () async {
      when(() => functionCaller('research-analyze', any())).thenAnswer(
        (_) async => <String, dynamic>{
          'run_id': 'run-1',
          'status': 'completed',
          'findings': <Map<String, dynamic>>[],
        },
      );

      final Result<ResearchOutcome> result = await gateway.analyze(request());

      expect(result.errorOrNull?.code, 'invalid_response');
    });

    test('rejects an out-of-contract question locally', () async {
      final Result<ResearchOutcome> result = await gateway.analyze(
        request(question: 'x'),
      );

      expect(result.errorOrNull?.code, 'invalid_request');
      verifyNever(() => functionCaller(any(), any()));
    });
  });

  group('SupabaseResearchGateway reads', () {
    test('fetchRuns parses statuses and caps the newest-first rows', () async {
      when(() => rpcCaller('list_research_runs', any())).thenAnswer(
        (_) async => PostgrestResponse<dynamic>(
          data: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'run-2',
              'organization_id': 'org-1',
              'matter_id': null,
              'status': 'completed',
              'model': 'deepseek',
              'prompt_summary': 'Second question',
              'error_code': null,
              'created_at': '2026-10-22T10:00:00Z',
              'completed_at': '2026-10-22T10:00:10Z',
            },
            <String, dynamic>{
              'id': 'run-1',
              'organization_id': 'org-1',
              'matter_id': 'matter-1',
              'status': 'failed',
              'model': null,
              'prompt_summary': 'First question',
              'error_code': 'provider_unavailable',
              'created_at': '2026-10-22T09:00:00Z',
              'completed_at': '2026-10-22T09:00:10Z',
            },
          ],
          count: 0,
        ),
      );

      final Result<List<ResearchRun>> result = await gateway.fetchRuns(
        limit: 1,
      );

      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.single.id, 'run-2');
      expect(
        result.valueOrNull!.single.status,
        ResearchRunStatus.completed,
      );
      verify(
        () => rpcCaller('list_research_runs', <String, dynamic>{
          'p_organization_id': 'org-1',
        }),
      ).called(1);
    });

    test('fetchFindings parses persisted rows and source ids', () async {
      when(() => rpcCaller('list_research_findings', any())).thenAnswer(
        (_) async => PostgrestResponse<dynamic>(
          data: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'finding-1',
              'run_id': 'run-1',
              'organization_id': 'org-1',
              'headline': 'Stored headline',
              'summary': 'Stored summary.',
              'excerpt': 'Stored excerpt.',
              'source_type': 'matter',
              'source_id': 'matter-1',
              'sort_order': 0,
              'created_at': '2026-10-22T10:00:00Z',
            },
          ],
          count: 0,
        ),
      );

      final Result<List<AiFinding>> result = await gateway.fetchFindings(
        'run-1',
      );

      final AiFinding finding = result.valueOrNull!.single;
      expect(finding.id, 'finding-1');
      expect(finding.sources.single.kind, AiSourceKind.matter);
      expect(finding.sources.single.sourceId, 'matter-1');
      verify(
        () => rpcCaller('list_research_findings', <String, dynamic>{
          'p_run_id': 'run-1',
        }),
      ).called(1);
    });

    test('a missing organization is a typed failure with no network call', () async {
      final SupabaseResearchGateway noOrg = SupabaseResearchGateway(
        SupabaseResearchApiImpl(
          functionCaller: functionCaller.call,
          rpcCaller: rpcCaller.call,
        ),
        organizationId: () => null,
      );

      final Result<List<ResearchRun>> runs = await noOrg.fetchRuns();
      expect(runs.errorOrNull?.code, 'invalid_request');

      verifyNever(() => rpcCaller(any(), any()));
      verifyNever(() => functionCaller(any(), any()));
    });

    test('a PostgREST denial maps to a denied AppError', () async {
      when(
        () => rpcCaller('list_research_runs', any()),
      ).thenThrow(
        PostgrestException(
          message: 'permission denied for function list_research_runs',
          code: '42501',
        ),
      );

      final Result<List<ResearchRun>> result = await gateway.fetchRuns();

      expect(result.errorOrNull?.code, 'forbidden');
      expect(result.errorOrNull?.kind, AppErrorKind.denied);
    });
  });
}
