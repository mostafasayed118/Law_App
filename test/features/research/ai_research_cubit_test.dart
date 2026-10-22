import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/research/data/synthetic_ai_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'package:legalhub/features/research/presentation/ai_research_cubit.dart';
import 'package:legalhub/features/research/presentation/ai_research_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockAiGateway extends Mock implements AiGateway {}

void main() {
  late _MockAiGateway gateway;

  setUpAll(() {
    registerFallbackValue(const Result<List<AiFinding>>.success(<AiFinding>[]));
    registerFallbackValue(
      ResearchRequest(organizationId: 'org-1', question: 'Question'),
    );
  });

  setUp(() {
    gateway = _MockAiGateway();
  });

  group('AiResearchCubit', () {
    test('starts idle with an empty success and no last query', () {
      expect(
        const AiResearchState().findings,
        isA<ViewSuccess<List<AiFinding>>>(),
      );
      expect(const AiResearchState().lastQuery, isEmpty);
    });

    blocTest<AiResearchCubit, AiResearchState>(
      'emits loading → success on a matching query (AC-4)',
      build: () {
        when(() => gateway.research(any())).thenAnswer(
          (_) async => Result<List<AiFinding>>.success(<AiFinding>[
            const AiFinding(
              id: 'research-doc-1',
              headline: 'Research note — Demo engagement letter',
              summary: 'Demo summary.',
              excerpt: 'Demo excerpt.',
              sources: <AiSource>[
                AiSource(
                  kind: AiSourceKind.document,
                  title: 'Demo engagement letter',
                  detail: 'contract',
                ),
              ],
            ),
          ]),
        );
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) => cubit.research('engagement letter'),
      expect: () => <AiResearchState>[
        const AiResearchState(
          findings: ViewLoading<List<AiFinding>>(),
          lastQuery: 'engagement letter',
        ),
        const AiResearchState(
          findings: ViewSuccess<List<AiFinding>>(<AiFinding>[
            AiFinding(
              id: 'research-doc-1',
              headline: 'Research note — Demo engagement letter',
              summary: 'Demo summary.',
              excerpt: 'Demo excerpt.',
              sources: <AiSource>[
                AiSource(
                  kind: AiSourceKind.document,
                  title: 'Demo engagement letter',
                  detail: 'contract',
                ),
              ],
            ),
          ]),
          lastQuery: 'engagement letter',
        ),
      ],
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'emits loading → error on gateway failure (AC-3/AC-4)',
      build: () {
        when(() => gateway.research(any())).thenAnswer(
          (_) async => const Result<List<AiFinding>>.failure(
            AppError(code: 'doc-fail', userMessage: 'documents unavailable'),
          ),
        );
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) => cubit.research('anything'),
      expect: () => <AiResearchState>[
        const AiResearchState(
          findings: ViewLoading<List<AiFinding>>(),
          lastQuery: 'anything',
        ),
        const AiResearchState(
          findings: ViewError<List<AiFinding>>(
            AppError(code: 'doc-fail', userMessage: 'documents unavailable'),
          ),
          lastQuery: 'anything',
          lastError: AppError(
            code: 'doc-fail',
            userMessage: 'documents unavailable',
          ),
        ),
      ],
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'duplicate submit while loading is a no-op (AC-4)',
      build: () {
        when(() => gateway.research(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Result<List<AiFinding>>.success(<AiFinding>[]);
        });
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) async {
        final Future<void> first = cubit.research('first query');
        final Future<void> second = cubit.research('second query');
        await first;
        await second;
      },
      // Only the first query runs: loading (first) → success (first). The
      // duplicate dispatch is dropped, and `lastQuery` stays on the first.
      expect: () => <AiResearchState>[
        const AiResearchState(
          findings: ViewLoading<List<AiFinding>>(),
          lastQuery: 'first query',
        ),
        const AiResearchState(
          findings: ViewSuccess<List<AiFinding>>(<AiFinding>[]),
          lastQuery: 'first query',
        ),
      ],
      verify: (_) {
        verify(() => gateway.research('first query')).called(1);
        verifyNever(() => gateway.research('second query'));
      },
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'blank query is a no-op (screen blocks; cubit re-asserts)',
      build: () => AiResearchCubit(gateway),
      act: (AiResearchCubit cubit) async {
        await cubit.research('   ');
        await cubit.research('');
      },
      expect: () => <AiResearchState>[],
      verify: (_) => verifyNever(() => gateway.research(any())),
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'a second query replaces the first answer — last answer only (D-R2/AC-7)',
      build: () {
        when(() => gateway.research('first query')).thenAnswer(
          (_) async => Result<List<AiFinding>>.success(<AiFinding>[
            const AiFinding(
              id: 'research-doc-1',
              headline: 'First answer',
              summary: 'Demo summary.',
              excerpt: 'Demo excerpt.',
              sources: <AiSource>[
                AiSource(
                  kind: AiSourceKind.matter,
                  title: 'Demo matter',
                  detail: 'corporate',
                ),
              ],
            ),
          ]),
        );
        when(() => gateway.research('second query')).thenAnswer(
          (_) async => const Result<List<AiFinding>>.success(<AiFinding>[]),
        );
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) async {
        await cubit.research('first query');
        await cubit.research('second query');
      },
      // The final state answers ONLY the second query: empty success with
      // lastQuery 'second query'. The first answer is dropped, never stacked
      // (no transcript).
      expect: () => <AiResearchState>[
        const AiResearchState(
          findings: ViewLoading<List<AiFinding>>(),
          lastQuery: 'first query',
        ),
        const AiResearchState(
          findings: ViewSuccess<List<AiFinding>>(<AiFinding>[
            AiFinding(
              id: 'research-doc-1',
              headline: 'First answer',
              summary: 'Demo summary.',
              excerpt: 'Demo excerpt.',
              sources: <AiSource>[
                AiSource(
                  kind: AiSourceKind.matter,
                  title: 'Demo matter',
                  detail: 'corporate',
                ),
              ],
            ),
          ]),
          lastQuery: 'first query',
        ),
        const AiResearchState(
          findings: ViewLoading<List<AiFinding>>(),
          lastQuery: 'second query',
        ),
        const AiResearchState(
          findings: ViewSuccess<List<AiFinding>>(<AiFinding>[]),
          lastQuery: 'second query',
        ),
      ],
    );

    test(
      'integration: real synthetic engine answers through the seam (AC-1/AC-2)',
      () async {
        final AiGateway real = SyntheticAiGateway(
          documentGateway: FakeDocumentGateway(),
          matterGateway: FakeMatterGateway(),
        );
        final Result<List<AiFinding>> result = await real.research(
          'settlement draft',
        );
        expect(result.valueOrNull, isNotEmpty);
      },
    );

    const AiFinding finding = AiFinding(
      id: 'finding-1',
      headline: 'Server headline',
      summary: 'Server summary.',
      excerpt: 'Server excerpt.',
      sources: <AiSource>[
        AiSource(
          kind: AiSourceKind.document,
          title: '',
          detail: '',
          sourceId: 'doc-1',
        ),
      ],
    );
    final ResearchRun run = ResearchRun(
      id: 'run-1',
      organizationId: 'org-1',
      status: ResearchRunStatus.completed,
      promptSummary: 'What changed?',
      createdAt: DateTime.utc(2026, 10, 22),
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'generate renders the outcome and refreshes the run history',
      build: () {
        when(() => gateway.analyze(any())).thenAnswer(
          (_) async => Result<ResearchOutcome>.success(
            ResearchOutcome(
              runId: 'run-1',
              status: ResearchRunStatus.completed,
              findings: const <AiFinding>[finding],
            ),
          ),
        );
        when(() => gateway.fetchRuns()).thenAnswer(
          (_) async => Result<List<ResearchRun>>.success(<ResearchRun>[run]),
        );
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) => cubit.generate(
        ResearchRequest(
          organizationId: 'org-1',
          documentIds: const <String>['doc-1'],
          question: 'What changed?',
        ),
      ),
      verify: (AiResearchCubit cubit) {
        final AiResearchState last = cubit.state;
        expect(last.findings, isA<ViewSuccess<List<AiFinding>>>());
        expect(
          (last.findings as ViewSuccess<List<AiFinding>>).data,
          const <AiFinding>[finding],
        );
        expect(last.runs, isA<ViewSuccess<List<ResearchRun>>>());
        expect(last.lastQuery, 'What changed?');
        expect(last.lastError, isNull);
        verify(() => gateway.analyze(any())).called(1);
        verify(() => gateway.fetchRuns()).called(1);
      },
    );

    blocTest<AiResearchCubit, AiResearchState>(
      'provider_not_configured keeps the typed error and an empty arm',
      build: () {
        when(() => gateway.analyze(any())).thenAnswer(
          (_) async => const Result<ResearchOutcome>.failure(
            AppError(
              code: 'provider_not_configured',
              userMessage: 'not configured',
              kind: AppErrorKind.unavailable,
            ),
          ),
        );
        when(() => gateway.fetchRuns()).thenAnswer(
          (_) async => const Result<List<ResearchRun>>.success(<ResearchRun>[]),
        );
        return AiResearchCubit(gateway);
      },
      act: (AiResearchCubit cubit) => cubit.generate(
        ResearchRequest(organizationId: 'org-1', question: 'What changed?'),
      ),
      verify: (AiResearchCubit cubit) {
        final AiResearchState last = cubit.state;
        expect(last.findings, isA<ViewEmpty<List<AiFinding>>>());
        expect(last.lastError?.code, 'provider_not_configured');
      },
    );

    test('loadRunFindings labels the answer with the run prompt', () async {
      when(() => gateway.fetchRuns()).thenAnswer(
        (_) async => Result<List<ResearchRun>>.success(<ResearchRun>[run]),
      );
      when(() => gateway.fetchFindings('run-1')).thenAnswer(
        (_) async =>
            const Result<List<AiFinding>>.success(<AiFinding>[finding]),
      );
      final AiResearchCubit cubit = AiResearchCubit(gateway);
      addTearDown(cubit.close);

      await cubit.loadRuns();
      await cubit.loadRunFindings('run-1');

      expect(cubit.state.lastQuery, 'What changed?');
      expect(cubit.state.findings, isA<ViewSuccess<List<AiFinding>>>());
    });
  });
}
