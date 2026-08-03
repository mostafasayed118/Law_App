import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/features/documents/presentation/document_list_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpVault(WidgetTester tester) async {
    // DocumentListScreen resolves DocumentGateway from the locator (the dev
    // fake in env-less runs).
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
        home: const DocumentListScreen(),
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

      // Rows are not tap targets: no chevron (contrast the matter list,
      // where every row carries the details affordance) and no InkWell
      // anywhere in the list (D-V1 — there is no details route).
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      // The vault carries the metadata-only, local-only note (R1/D-V1).
      expect(
        find.textContaining('synthetic document metadata only'),
        findsOneWidget,
      );
    });

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
