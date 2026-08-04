import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/documents/data/fake_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';

void main() {
  group('FakeDocumentGateway.fetchDocuments (AC-1)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeDocumentGateway gateway = FakeDocumentGateway();

      final List<Document>? first =
          (await gateway.fetchDocuments()).valueOrNull;
      final List<Document>? second =
          (await gateway.fetchDocuments()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeDocumentGateway.syntheticDocuments);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('documents carry only non-PII metadata fields (D-V4 shape)', () async {
      final FakeDocumentGateway gateway = FakeDocumentGateway();

      final List<Document> documents =
          (await gateway.fetchDocuments()).valueOrNull!;

      // Every synthetic document exposes the D-V4 surface: id / generic
      // demo title / matter reference / document type / created date.
      // Metadata only — the string forms must never render contact or
      // client-identity shapes (no email/phone/address).
      for (final Document document in documents) {
        expect(document.id, isNotEmpty);
        expect(document.title, isNotEmpty);
        expect(document.matterRef, isNotEmpty);
        expect(document.type, isA<DocumentType>());
        expect(document.toString(), isNot(contains('@')));
      }
    });

    test(
      'every document references a known synthetic matter title (D-W2)',
      () async {
        final FakeDocumentGateway gateway = FakeDocumentGateway();

        final List<Document> documents =
            (await gateway.fetchDocuments()).valueOrNull!;

        // D-W2 pin (matter_workspace_scope_2026-08-04.md §2 D-W2, risk R1):
        // each document's matterRef is one of the known synthetic matter
        // titles (the same set MessageThread.matterRef uses, D-MSG4) — the
        // per-matter association must never read as a real case reference.
        const Set<String> knownMatterTitles = <String>{
          'Demo acquisition review',
          'Commercial lease consultation',
          'Procedural review matter',
          'Family status consultation',
          'Startup formation advisory',
        };
        for (final Document document in documents) {
          expect(
            knownMatterTitles,
            contains(document.matterRef),
            reason: 'document ${document.id} references an unknown matter',
          );
        }
        // Every known matter has at least one synthetic document, so the
        // per-matter workspace view never dead-ends into an always-empty
        // section for a matter that exists in the demo roster.
        for (final String title in knownMatterTitles) {
          expect(
            documents.where((Document d) => d.matterRef == title),
            isNotEmpty,
            reason: 'no synthetic document for $title',
          );
        }
      },
    );

    test('covers every document type in the chip set', () async {
      final FakeDocumentGateway gateway = FakeDocumentGateway();

      final List<Document> documents =
          (await gateway.fetchDocuments()).valueOrNull!;

      // The vault surface's type chips must each have at least one document
      // behind them, or a filter would dead-end into an always-empty list.
      for (final DocumentType type in DocumentType.values) {
        expect(
          documents.where((Document d) => d.type == type),
          isNotEmpty,
          reason: 'no synthetic document for $type',
        );
      }
    });
  });
}
