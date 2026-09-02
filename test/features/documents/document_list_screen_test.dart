import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/documents/presentation/document_list_screen.dart';
import 'package:legalhub/features/matters/presentation/matter_link_chip.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpVault(
    WidgetTester tester, {
    RoleCapability? capabilities,
  }) async {
    // Default to the client's real capability map (the D-C4 posture: the
    // chip renders under canViewMatters, true for every bootstrap role).
    final RoleCapability effectiveCapabilities =
        capabilities ?? roleCapabilities[UserRole.client]!;
    // DocumentListScreen resolves DocumentGateway/MatterGateway from the
    // locator (the dev fakes in env-less runs).
    configureDependencies();
    // A tall surface so the full synthetic list builds inside the ListView.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DocumentListScreen(capabilities: effectiveCapabilities),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The tiles render the created date through the same locale-aware shape
  // as the matter details surface (DateFormat.yMMMd(l10n.localeName)); the
  // test re-computes the expected string so the assertion survives locale
  // changes.
  String dateLabel(DateTime date) => DateFormat.yMMMd('en').format(date);

  group('document vault surface (Phase 8 slice 8.1)', () {
    testWidgets('lists the synthetic document metadata from the fake (AC-1)', (
      tester,
    ) async {
      await pumpVault(tester);

      expect(find.text('Documents'), findsOneWidget);
      for (final Document document in FakeDocumentGateway.syntheticDocuments) {
        expect(find.text(document.title), findsOneWidget);
      }
      // Every row pairs the title with its type + created date (the three
      // D-V4 metadata fields).
      expect(
        find.text('Contract · ${dateLabel(DateTime.utc(2026, 7, 10))}'),
        findsOneWidget,
      );
      expect(
        find.text('Correspondence · ${dateLabel(DateTime.utc(2026, 7, 22))}'),
        findsOneWidget,
      );
    });

    testWidgets('renders metadata only — no body, preview, download, or row '
        'affordance (AC-2)', (tester) async {
      await pumpVault(tester);

      // Absence of any content affordance: no download / preview / open
      // icons and no action labels anywhere in the vault.
      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
      expect(find.textContaining('Preview'), findsNothing);
      expect(find.textContaining('Download'), findsNothing);

      // D-V1 re-scoped by Phase 12 D-C2: rows still carry no chevron (contrast
      // the matter list, where every row carries the details affordance), and
      // the ONLY InkWell in the list lives inside a resolved row's "View
      // matter" chip — the reverse cross-link affordance. Unresolved rows
      // keep no tap target at all.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final Finder listInkWells = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(InkWell),
      );
      final Finder chipInkWells = find.descendant(
        of: find.byType(MatterLinkChip),
        matching: find.byType(InkWell),
      );
      // Every synthetic document's matterRef resolves to a known matter, so
      // every row carries exactly one chip — and no other InkWell exists in
      // the list (the chip is the only tap target, D-C2).
      expect(chipInkWells, findsNWidgets(5));
      expect(listInkWells.evaluate().length, chipInkWells.evaluate().length);

      // The vault carries the metadata-only, local-only note (R1/D-V1).
      expect(
        find.textContaining('synthetic document metadata only'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a resolved row renders the View matter chip; an unresolved matterRef '
      'renders none (D-C2/D-C3)',
      (tester) async {
        // Gateway stub whose only document carries an unknown matterRef (not
        // one of the 5 known synthetic matter titles) — registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<DocumentGateway>(
          _UnresolvedRefDocumentGateway.new,
        );

        await pumpVault(tester);

        // The row renders its metadata but NO chip: the title-keyed
        // resolution found no matter (D-C3), so the row is not a tap target.
        expect(find.text('Unlinked demo file'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      'the View matter chip is gated by canViewMatters — no chip without the '
      'nav hint (D-C4)',
      (tester) async {
        // A capability projection without canViewMatters: every document row
        // still resolves, but the reverse cross-link must not render (the
        // D-W5 posture — navigation hints only).
        await pumpVault(
          tester,
          capabilities: const RoleCapability(
            canViewHome: true,
            canViewSettings: true,
            canBookConsultation: true,
            canViewAttorneyDiscovery: true,
            canViewMatters: false,
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

        expect(find.text('Demo engagement letter'), findsOneWidget);
        expect(find.byType(MatterLinkChip), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an empty result set renders the localized empty state (AC-2)',
      (tester) async {
        // Stub gateway returning an empty list, registered before
        // configureDependencies so the fake registration is skipped.
        await resetServiceLocator();
        serviceLocator.registerLazySingleton<DocumentGateway>(
          _EmptyDocumentGateway.new,
        );

        await pumpVault(tester);

        expect(find.text('No documents are available.'), findsOneWidget);
        expect(find.text('Demo engagement letter'), findsNothing);
      },
    );
  });
}

/// Gateway stub that yields an empty document list (empty-state widget pin).
class _EmptyDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async {
    return Result<List<Document>>.success(const <Document>[]);
  }
}

/// Gateway stub whose single document carries an UNKNOWN matterRef — the
/// D-C3 unresolved-row case (no synthetic matter title matches, so the row
/// must render no reverse cross-link chip).
class _UnresolvedRefDocumentGateway implements DocumentGateway {
  @override
  Future<Result<List<Document>>> fetchDocuments() async {
    return Result<List<Document>>.success(<Document>[
      Document(
        id: 'doc-x',
        title: 'Unlinked demo file',
        matterRef: 'No such synthetic matter',
        type: DocumentType.contract,
        createdAt: DateTime.utc(2026, 7, 1),
      ),
    ]);
  }
}
