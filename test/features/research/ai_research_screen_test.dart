import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/matters/data/fake_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/research/presentation/ai_research_entry_card.dart';
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
  Future<Result<List<Document>>> fetchDocuments() async =>
      Result<List<Document>>.success(documents);
}

class _StubMatterGateway implements MatterGateway {
  _StubMatterGateway(this.matters);
  final List<Matter> matters;

  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      Result<List<Matter>>.success(matters);
}

class _FailingDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async =>
      Result<List<Document>>.failure(_loadFailure);
}

class _FailingMatterGateway implements MatterGateway {
  @override
  Future<Result<List<Matter>>> fetchMatters() async =>
      Result<List<Matter>>.failure(_loadFailure);
}

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
  }) async {
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
        expect(find.text('Sources'), findsOneWidget);
        expect(
          find.textContaining('Demo settlement draft — contract'),
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

    testWidgets('entry card renders its localized copy (AC-6 wiring)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AiResearchEntryCard(onTap: null)),
        ),
      );
      await tester.pump();

      expect(find.text('AI research'), findsOneWidget);
      expect(
        find.text('Ask the demo research assistant — advisory only.'),
        findsOneWidget,
      );
    });
  });
}
