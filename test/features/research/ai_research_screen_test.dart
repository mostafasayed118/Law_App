import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/local/in_memory_org_selection_store.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/research/domain/ai_finding.dart';
import 'package:legalhub/features/research/domain/ai_gateway.dart';
import 'package:legalhub/features/research/domain/research_outcome.dart';
import 'package:legalhub/features/research/domain/research_request.dart';
import 'package:legalhub/features/research/domain/research_run.dart';
import 'package:legalhub/features/research/presentation/ai_research_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Registers a synthetic engine over stubbed upstream seams so screen tests
/// control the corpus results deterministically (the DI-pin pattern).
Future<void> _registerStub({
  List<Document> documents = const <Document>[],
  List<Matter> matters = const <Matter>[],
}) async {
  await resetServiceLocator();
  serviceLocator.registerLazySingleton<DocumentGateway>(
    () => _StubDocumentGateway(documents),
  );
  serviceLocator.registerLazySingleton<MatterGateway>(
    () => _StubMatterGateway(matters),
  );
}

final AppError _loadFailure = AppError(
  code: 'doc-fail',
  userMessage: 'documents unavailable',
);

class _StubDocumentGateway implements DocumentGateway {
  _StubDocumentGateway(this.documents);
  final List<Document> documents;

  @override
  Future<Result<List<Document>>> fetchDocuments({String? matterId}) async =>
      Result<List<Document>>.success(documents);

  @override
  Future<Result<List<Document>>> searchDocuments(
    String query, {
    int limit = 30,
  }) => fetchDocuments();
}

class _StubMatterGateway implements MatterGateway {
  _StubMatterGateway(this.matters);
  final List<Matter> matters;

  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      Result<List<Matter>>.success(matters);

  @override
  Future<Result<List<Matter>>> searchMatters(String query, {int limit = 30}) =>
      fetchMatters();
}

class _FailingDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments({String? matterId}) async =>
      Result<List<Document>>.failure(_loadFailure);

  @override
  Future<Result<List<Document>>> searchDocuments(
    String query, {
    int limit = 30,
  }) => fetchDocuments();
}

class _FailingMatterGateway implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      Result<List<Matter>>.failure(_loadFailure);

  @override
  Future<Result<List<Matter>>> searchMatters(String query, {int limit = 30}) =>
      fetchMatters();
}

/// A configurable real-seam stub: one outcome, one typed failure, a run
/// history, and stored findings. Captures the request the screen generates.
class _StubAiGateway implements AiGateway {
  _StubAiGateway({
    this.outcome,
    this.analyzeError,
    this.runs = const <ResearchRun>[],
    this.findings = const <AiFinding>[],
  });

  final ResearchOutcome? outcome;
  final AppError? analyzeError;
  final List<ResearchRun> runs;
  final List<AiFinding> findings;
  ResearchRequest? lastRequest;

  @override
  Future<Result<ResearchOutcome>> analyze(ResearchRequest request) async {
    lastRequest = request;
    final AppError? error = analyzeError;
    if (error != null) {
      return Result<ResearchOutcome>.failure(error);
    }
    return Result<ResearchOutcome>.success(outcome!);
  }

  @override
  Future<Result<List<AiFinding>>> fetchFindings(String runId) async =>
      Result<List<AiFinding>>.success(findings);

  @override
  Future<Result<List<ResearchRun>>> fetchRuns({int limit = 20}) async =>
      Result<List<ResearchRun>>.success(runs);

  @override
  Future<Result<List<AiFinding>>> research(String query) async =>
      const Result<List<AiFinding>>.success(<AiFinding>[]);
}

ResearchOutcome _outcome(List<AiFinding> findings) => ResearchOutcome(
  runId: 'run-1',
  status: ResearchRunStatus.completed,
  model: 'test-model',
  findings: findings,
);

AiFinding _serverFinding({String headline = 'Server headline'}) => AiFinding(
  id: 'finding-1',
  headline: headline,
  summary: 'Server summary.',
  excerpt: 'Server excerpt.',
  sources: const <AiSource>[
    AiSource(
      kind: AiSourceKind.document,
      title: '',
      detail: '',
      sourceId: 'doc-5',
    ),
  ],
);

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpResearch(
    WidgetTester tester, {
    RoleCapability capabilities = const RoleCapability(
      canViewHome: true,
      canViewSettings: true,
      canBookConsultation: true,
      canViewAttorneyDiscovery: true,
      canViewMatters: true,
      canViewDocuments: true,
      canViewMessages: true,
      canViewFiles: true,
      canViewAudit: false,
      canViewNotifications: true,
      canViewAlerts: true,
      canViewTasks: true,
      canViewApprovals: true,
      canUseAiResearch: true,
    ),
    AiGateway? aiGateway,
    bool localOnly = true,
    String? activeOrganizationId,
  }) async {
    if (aiGateway != null) {
      serviceLocator.registerLazySingleton<AiGateway>(() => aiGateway);
    }
    if (!localOnly) {
      serviceLocator.registerLazySingleton<BackendPosture>(
        () => const BackendPosture(isLocalOnly: false),
      );
    }
    if (activeOrganizationId != null) {
      final ActiveOrgStore store = ActiveOrgStore(InMemoryOrgSelectionStore());
      store.select(activeOrganizationId);
      serviceLocator.registerLazySingleton<ActiveOrgStore>(() => store);
    }
    configureDependencies();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiResearchScreen(capabilities: capabilities),
      ),
    );
    await tester.pump();
  }

  group('AI research screen (AI research slice, plan 2026-09-02)', () {
    testWidgets('idle state renders the persistent advisory banner (AC-5)', (
      tester,
    ) async {
      await _registerStub();
      await pumpResearch(tester);

      expect(find.byType(AiResearchScreen), findsOneWidget);
      expect(
        find.textContaining('AI-suggested'),
        findsOneWidget,
        reason: 'the C-3 banner is persistent in every render state',
      );
      expect(
        find.text('Ask a question to search the demo research corpus.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'submitting a query renders findings with citations (AC-1/AC-2)',
      (tester) async {
        await _registerStub(
          documents: FakeDocumentGateway.syntheticDocuments,
          matters: FakeMatterGateway.syntheticMatters,
        );
        await pumpResearch(tester);

        await tester.enterText(find.byType(TextField), 'settlement draft');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(
          find.text('Research note — Demo settlement draft'),
          findsOneWidget,
        );
        // The citation row renders unconditionally under the finding (C-2).
        // Demo localization (2026-09-24): the detail resolves through the
        // document-type label (`contract` → `Contract`).
        expect(find.text('Sources'), findsOneWidget);
        expect(
          find.textContaining('Demo settlement draft — Contract'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a no-match query renders the honest empty state (AC-2)', (
      tester,
    ) async {
      await _registerStub(
        documents: FakeDocumentGateway.syntheticDocuments,
        matters: FakeMatterGateway.syntheticMatters,
      );
      await pumpResearch(tester);

      await tester.enterText(find.byType(TextField), 'zzz unmatched topic zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.text('No matches in the demo corpus. Try different words.'),
        findsOneWidget,
      );
      // The banner persists through the empty arm (C-3).
      expect(find.textContaining('AI-suggested'), findsOneWidget);
    });

    testWidgets('failure renders error + retry reissues (AC-3)', (
      tester,
    ) async {
      await resetServiceLocator();
      serviceLocator.registerLazySingleton<DocumentGateway>(
        _FailingDocumentGateway.new,
      );
      serviceLocator.registerLazySingleton<MatterGateway>(
        _FailingMatterGateway.new,
      );
      await pumpResearch(tester);

      await tester.enterText(find.byType(TextField), 'anything at all');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Unable to run the research query.'), findsOneWidget);
      // The banner persists through the error arm (C-3).
      expect(find.textContaining('AI-suggested'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to run the research query.'),
        findsOneWidget,
        reason: 'the stub keeps failing; retry reissues, no crash',
      );
    });

    testWidgets('no save/apply/export affordance exists anywhere (AC-5 pin)', (
      tester,
    ) async {
      await _registerStub(
        documents: FakeDocumentGateway.syntheticDocuments,
        matters: FakeMatterGateway.syntheticMatters,
      );
      await pumpResearch(tester);

      await tester.enterText(find.byType(TextField), 'settlement draft');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);
      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets(
      'a role without canUseAiResearch gets the distinct denial (AC-6)',
      (tester) async {
        await _registerStub();
        await pumpResearch(
          tester,
          capabilities: const RoleCapability(
            canViewHome: true,
            canViewSettings: true,
            canBookConsultation: true,
            canViewAttorneyDiscovery: true,
            canViewMatters: true,
            canViewDocuments: true,
            canViewMessages: true,
            canViewFiles: true,
            canViewAudit: false,
            canViewNotifications: true,
            canViewAlerts: true,
            canViewTasks: true,
            canViewApprovals: true,
            canUseAiResearch: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Access not available'), findsOneWidget);
        expect(
          find.byType(TextField),
          findsNothing,
          reason: 'the denied caller never reaches the research surface',
        );
      },
    );

    testWidgets(
      'renders the question field, optional pickers, and generate action',
      (tester) async {
        await _registerStub(
          documents: FakeDocumentGateway.syntheticDocuments,
          matters: FakeMatterGateway.syntheticMatters,
        );
        await pumpResearch(tester);
        await tester.pumpAndSettle();

        expect(find.text('Research question'), findsOneWidget);
        expect(find.text('Generate findings'), findsOneWidget);
        expect(find.text('Documents (optional)'), findsOneWidget);
        expect(find.byType(FilterChip), findsNWidgets(5));
        expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
        expect(
          find.text('Ask a question to search the demo research corpus.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'generate sends the selected context and renders a server finding',
      (tester) async {
        final _StubAiGateway stub = _StubAiGateway(
          outcome: _outcome(<AiFinding>[_serverFinding()]),
        );
        await _registerStub(
          documents: FakeDocumentGateway.syntheticDocuments,
          matters: FakeMatterGateway.syntheticMatters,
        );
        await pumpResearch(tester, aiGateway: stub);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Demo settlement draft'));
        await tester.pump();
        await tester.enterText(
          find.byType(TextField),
          'What changed in the draft?',
        );
        await tester.tap(find.text('Generate findings'));
        await tester.pumpAndSettle();

        expect(stub.lastRequest?.question, 'What changed in the draft?');
        expect(stub.lastRequest?.documentIds, contains('doc-5'));
        expect(stub.lastRequest?.organizationId, 'demo-organization');
        expect(find.text('Server headline'), findsOneWidget);
        expect(find.text('Server summary.'), findsOneWidget);
        expect(find.text('Document — doc-5'), findsOneWidget);
      },
    );

    testWidgets(
      'provider_not_configured renders an explicit unavailable state',
      (tester) async {
        final _StubAiGateway stub = _StubAiGateway(
          analyzeError: const AppError(
            code: 'provider_not_configured',
            userMessage: 'not configured',
            kind: AppErrorKind.unavailable,
          ),
        );
        await _registerStub(
          documents: FakeDocumentGateway.syntheticDocuments,
          matters: FakeMatterGateway.syntheticMatters,
        );
        await pumpResearch(
          tester,
          aiGateway: stub,
          localOnly: false,
          activeOrganizationId: 'org-1',
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'A valid question');
        await tester.tap(find.text('Generate findings'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'AI research is not configured for this deployment. '
            'No analysis was run.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Retry'),
          findsNothing,
          reason: 'a missing provider secret is not a retryable failure',
        );
      },
    );

    testWidgets('a typed failure renders its copy with a retry', (
      tester,
    ) async {
      final _StubAiGateway stub = _StubAiGateway(
        analyzeError: const AppError(
          code: 'context_too_large',
          userMessage: 'too large',
        ),
      );
      await _registerStub(
        documents: FakeDocumentGateway.syntheticDocuments,
        matters: FakeMatterGateway.syntheticMatters,
      );
      await pumpResearch(
        tester,
        aiGateway: stub,
        localOnly: false,
        activeOrganizationId: 'org-1',
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A valid question');
      await tester.tap(find.text('Generate findings'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The selected context is too large. '
          'Remove documents and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('run history renders statuses and opens stored findings', (
      tester,
    ) async {
      final _StubAiGateway stub = _StubAiGateway(
        runs: <ResearchRun>[
          ResearchRun(
            id: 'run-1',
            organizationId: 'org-1',
            status: ResearchRunStatus.completed,
            promptSummary: 'Prior question',
            createdAt: DateTime.utc(2026, 10, 22),
          ),
          ResearchRun(
            id: 'run-0',
            organizationId: 'org-1',
            status: ResearchRunStatus.failed,
            promptSummary: 'Broken question',
            errorCode: 'provider_unavailable',
            createdAt: DateTime.utc(2026, 10, 21),
          ),
        ],
        findings: <AiFinding>[_serverFinding(headline: 'Stored finding')],
      );
      await _registerStub(
        documents: FakeDocumentGateway.syntheticDocuments,
        matters: FakeMatterGateway.syntheticMatters,
      );
      await pumpResearch(tester, aiGateway: stub);
      await tester.pumpAndSettle();

      expect(find.text('Recent research runs'), findsOneWidget);
      expect(find.text('Prior question'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);

      await tester.tap(find.text('Prior question'));
      await tester.pumpAndSettle();

      expect(find.text('Stored finding'), findsOneWidget);
    });

    testWidgets('configured builds name the AI generation and storage', (
      tester,
    ) async {
      final _StubAiGateway stub = _StubAiGateway(
        outcome: _outcome(const <AiFinding>[]),
      );
      await _registerStub(
        documents: FakeDocumentGateway.syntheticDocuments,
        matters: FakeMatterGateway.syntheticMatters,
      );
      await pumpResearch(
        tester,
        aiGateway: stub,
        localOnly: false,
        activeOrganizationId: 'org-1',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AI-generated — review before relying on it'),
        findsOneWidget,
      );
      expect(
        find.text('AI-generated findings are stored with your organization.'),
        findsOneWidget,
      );
      expect(find.textContaining('Demo mode'), findsNothing);
    });
  });
}
