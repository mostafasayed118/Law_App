import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/documents/domain/document.dart';

void main() {
  group('DocumentType (D-V4 pin)', () {
    test('pins the document-type set', () {
      expect(DocumentType.values, <DocumentType>[
        DocumentType.contract,
        DocumentType.brief,
        DocumentType.evidence,
        DocumentType.correspondence,
      ]);
    });
  });

  group('Document VO (D-V4 shape)', () {
    test('is equatable on its synthetic metadata fields', () {
      final DateTime created = DateTime.utc(2026, 7, 10);
      final Document a = _document(created: created);
      final Document b = _document(created: created);
      final Document c = Document(
        id: 'doc-2',
        title: 'Sample matter brief — demo',
        type: DocumentType.brief,
        createdAt: created,
      );

      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}

Document _document({required DateTime created}) => Document(
  id: 'doc-1',
  title: 'Demo engagement letter',
  type: DocumentType.contract,
  createdAt: created,
);
