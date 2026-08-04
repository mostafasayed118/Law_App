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
        matterRef: 'Commercial lease consultation',
        type: DocumentType.brief,
        createdAt: created,
      );

      expect(a, equals(b));
      expect(a == c, isFalse);
    });

    test(
      'pins the full field surface — no body/content/size/download field '
      'can be added without failing (D-V1 metadata-only line, structural)',
      () {
        final Document document = _document(created: DateTime.utc(2026, 7, 10));

        // props enumerates the ENTIRE field surface: id / title / matterRef /
        // type / createdAt. The metadata-only line (D-V1) is enforced
        // structurally — any future body, content, size, or download-URL field
        // must enter props or fail this pin, so the vault can never render
        // document content.
        expect(document.props, <Object?>[
          'doc-1',
          'Demo engagement letter',
          'Demo acquisition review',
          DocumentType.contract,
          DateTime.utc(2026, 7, 10),
        ]);
      },
    );
  });
}

Document _document({required DateTime created}) => Document(
  id: 'doc-1',
  title: 'Demo engagement letter',
  matterRef: 'Demo acquisition review',
  type: DocumentType.contract,
  createdAt: created,
);
