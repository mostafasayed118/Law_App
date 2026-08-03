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
      // demo title / document type / created date. Metadata only — the
      // string forms must never render contact or client-identity shapes
      // (no email/phone/address).
      for (final Document document in documents) {
        expect(document.id, isNotEmpty);
        expect(document.title, isNotEmpty);
        expect(document.type, isA<DocumentType>());
        expect(document.toString(), isNot(contains('@')));
      }
    });

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
