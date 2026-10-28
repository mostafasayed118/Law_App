import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/backend_posture.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/features/search/presentation/search_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  RoleCapability capabilities({bool documents = true}) => RoleCapability(
    canViewHome: true,
    canViewSettings: true,
    canBookConsultation: true,
    canViewAttorneyDiscovery: true,
    canViewMatters: true,
    canViewDocuments: documents,
    canViewMessages: true,
    canViewFiles: true,
    canViewAudit: false,
    canViewNotifications: true,
    canViewAlerts: true,
    canViewTasks: true,
    canViewApprovals: true,
    canUseAiResearch: false,
  );

  Future<void> pumpSearch(
    WidgetTester tester, {
    String initialQuery = 'Demo',
    RoleCapability? caps,
    bool localOnly = true,
  }) async {
    // A configured build registers the real-backend posture; the env-less
    // default keeps the historical local-only posture.
    if (!localOnly) {
      serviceLocator.registerSingleton<BackendPosture>(
        const BackendPosture(isLocalOnly: false),
      );
    }
    // SearchScreen resolves the four gateways from the locator (the dev
    // fakes in env-less runs).
    configureDependencies();
    // A tall surface so the grouped result rows build inside the ListView.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(
          initialQuery: initialQuery,
          capabilities: caps ?? capabilities(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('search surface (Phase 11 slice 11.1)', () {
    testWidgets(
      'seeds a search from the query param and groups results by kind',
      (tester) async {
        await pumpSearch(tester);

        expect(find.text('Search'), findsOneWidget);
        // Capability-gated groups render for the matching subsets (D-S2):
        // 'demo' hits matters, documents, and threads — but no attorney
        // name/practice-area, so the attorney group is absent.
        expect(find.text('Matters'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Messages'), findsOneWidget);
        expect(find.text('Find an Attorney'), findsNothing);
        expect(find.text('Demo acquisition review'), findsOneWidget);
        expect(find.text('Demo engagement letter'), findsOneWidget);
        expect(find.text('Demo matter updates'), findsOneWidget);
        // Rows render the same metadata fields as the list surfaces.
        expect(find.text('Corporate · Layla Mansour'), findsOneWidget);
        // The surface carries the local-only demo note (D-S5/R1).
        expect(find.textContaining('synthetic lists only'), findsOneWidget);
      },
    );

    testWidgets('a blank query shows the no-query state, not results (D-S4)', (
      tester,
    ) async {
      await pumpSearch(tester, initialQuery: '   ');

      expect(
        find.text(
          'Type a search term to find demo matters, documents, messages, or attorneys.',
        ),
        findsOneWidget,
      );
      // The local-only note is part of the demo posture's truthful copy.
      expect(find.textContaining('Demo mode'), findsOneWidget);
      expect(find.text('Demo acquisition review'), findsNothing);
    });

    testWidgets(
      'configured posture hides the demo note and uses neutral no-query copy',
      (tester) async {
        await pumpSearch(tester, initialQuery: '   ', localOnly: false);

        expect(
          find.text(
            'Type a search term to search matters, documents, messages, and '
            'attorneys.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Type a search term to find demo matters, documents, messages, or '
            'attorneys.',
          ),
          findsNothing,
        );
        // A configured build searches server data: neither the synthetic-list
        // note nor any "demo mode" wording may render.
        expect(find.textContaining('Demo mode'), findsNothing);
        expect(find.textContaining('synthetic lists only'), findsNothing);
      },
    );

    testWidgets('configured results never carry the demo note', (tester) async {
      await pumpSearch(tester, localOnly: false);

      expect(find.text('Demo acquisition review'), findsOneWidget);
      expect(find.textContaining('Demo mode'), findsNothing);
      expect(find.textContaining('synthetic lists only'), findsNothing);
    });

    testWidgets('a query with no matches renders the localized empty state', (
      tester,
    ) async {
      await pumpSearch(tester, initialQuery: 'zzz');

      expect(find.text('No results match your search.'), findsOneWidget);
    });

    testWidgets(
      'renders metadata only — no send/reply, no composer, no message text '
      '(AC-2)',
      (tester) async {
        await pumpSearch(tester);

        // The surface must never read as a message composer or thread-open
        // affordance (the Phase 8/9 AC-2 absence lines, extended).
        expect(find.byIcon(Icons.send), findsNothing);
        expect(find.byIcon(Icons.attach_file), findsNothing);
        // The only text field is the search field itself — no composer.
        expect(find.byType(TextField), findsOneWidget);
        // Thread rows render participants (metadata) — never a body or
        // preview; the body-less line holds structurally.
        expect(
          find.textContaining('Layla Mansour, Demo client'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a group hides when its capability is not granted (D-S2)', (
      tester,
    ) async {
      await pumpSearch(tester, caps: capabilities(documents: false));

      expect(find.text('Documents'), findsNothing);
      expect(find.text('Demo engagement letter'), findsNothing);
      // Sibling groups still render under their own capabilities.
      expect(find.text('Matters'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets(
      'typing in the field re-searches after the debounce (D-S4 refine)',
      (tester) async {
        await pumpSearch(tester);
        // Seeded query shows the documents group.
        expect(find.text('Demo engagement letter'), findsOneWidget);

        // A refined query re-runs the client-side search after the debounce
        // window; 'Corporate' matches matters + attorneys only.
        await tester.enterText(find.byType(TextField), 'Corporate');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Demo engagement letter'), findsNothing);
        expect(find.text('Layla Mansour'), findsOneWidget);
        expect(find.text('Matters'), findsOneWidget);
        expect(find.text('Find an Attorney'), findsOneWidget);
      },
    );

    testWidgets(
      'a single-group failure shows partial results with an unavailable '
      'notice, and re-search recovers',
      (tester) async {
        // A flaky matter gateway (failure then success) registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<MatterGateway>(
          _FlakyMatterGateway.new,
        );

        await pumpSearch(tester);

        // The good groups still render; the failed matters group drops its
        // section and the partial-results notice says results may be
        // incomplete (audit: fail-fast search).
        expect(
          find.text(
            'Some sources were unavailable — results may be incomplete.',
          ),
          findsOneWidget,
        );
        expect(find.text('Matters'), findsNothing);
        expect(find.text('Demo acquisition review'), findsNothing);
        expect(find.text('Demo engagement letter'), findsOneWidget);
        expect(find.text('Demo matter updates'), findsOneWidget);

        // Re-running the search hits the recovered gateway: the notice
        // clears and the matters section returns. The trailing space keeps
        // the trimmed query identical while still firing onChanged (an
        // identical enterText is a no-op in the field).
        await tester.enterText(find.byType(TextField), 'Demo ');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Some sources were unavailable — results may be incomplete.',
          ),
          findsNothing,
        );
        expect(find.text('Demo acquisition review'), findsOneWidget);
      },
    );
  });
}

/// Matter gateway that fails once, then succeeds — pins the search surface's
/// error + retry path end to end.
class _FlakyMatterGateway implements MatterGateway {
  _FlakyMatterGateway() : _calls = 0;

  int _calls;

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    _calls += 1;
    if (_calls == 1) {
      return Result<List<Matter>>.failure(
        const AppError(
          code: 'search_failed',
          userMessage: 'Unable to run the search.',
        ),
      );
    }
    return Result<List<Matter>>.success(_syntheticMatters);
  }

  @override
  Future<Result<List<Matter>>> searchMatters(String query, {int limit = 30}) =>
      fetchMatters();
}

final List<Matter> _syntheticMatters = <Matter>[
  Matter(
    id: 'matter-1',
    title: 'Demo acquisition review',
    practiceArea: PracticeArea.corporate,
    status: MatterStatus.active,
    assignedAttorneyName: 'Layla Mansour',
    createdAt: DateTime.utc(2026, 7, 12),
  ),
];
