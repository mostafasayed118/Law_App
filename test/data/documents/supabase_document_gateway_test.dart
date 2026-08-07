import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/documents/supabase_document_api.dart';
import 'package:legalhub/data/documents/supabase_document_gateway.dart';
import 'package:legalhub/features/documents/domain/document.dart';

/// Hand-rolled fake of the [SupabaseDocumentApi] seam: records calls and
/// answers with canned rows or a [SupabaseDocumentException], so the
/// gateway's domain mapping is tested without a provider.
class _StubSupabaseDocumentApi implements SupabaseDocumentApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseDocumentException? error;

  @override
  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    if (error != null) {
      throw error!;
    }
    return rows;
  }
}

Map<String, dynamic> _row({
  String id = 'doc-1',
  String matterId = 'm-1',
  String title = 'Demo engagement letter',
  String documentType = 'contract',
  Object? matters = const <String, dynamic>{'title': 'Demo acquisition review'},
  String createdAt = '2026-08-07T10:00:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'matter_id': matterId,
  'title': title,
  'document_type': documentType,
  'created_at': createdAt,
  'matters': matters,
};

void main() {
  late _StubSupabaseDocumentApi api;
  late SupabaseDocumentGateway gateway;

  setUp(() {
    api = _StubSupabaseDocumentApi();
    gateway = SupabaseDocumentGateway(api);
  });

  group('row → Document mapping (D-DR7)', () {
    test(
      'maps a full row to the Document VO with the embedded matter title',
      () async {
        api.rows = <Map<String, dynamic>>[_row()];

        final Result<List<Document>> result = await gateway.fetchDocuments();

        expect(result.isSuccess, isTrue);
        final Document document = result.valueOrNull!.single;
        expect(document.id, 'doc-1');
        expect(document.title, 'Demo engagement letter');
        expect(document.matterRef, 'Demo acquisition review');
        expect(document.type, DocumentType.contract);
        expect(
          document.createdAt,
          DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
        );
      },
    );

    test('maps every document_type name', () async {
      api.rows = <Map<String, dynamic>>[
        _row(id: 'doc-1', documentType: 'contract'),
        _row(id: 'doc-2', documentType: 'brief'),
        _row(id: 'doc-3', documentType: 'evidence'),
        _row(id: 'doc-4', documentType: 'correspondence'),
      ];

      final List<Document> documents =
          (await gateway.fetchDocuments()).valueOrNull!;

      expect(documents.map((Document d) => d.type), <DocumentType>[
        DocumentType.contract,
        DocumentType.brief,
        DocumentType.evidence,
        DocumentType.correspondence,
      ]);
    });

    test(
      'resolves matterRef from the embedded matters(title) select (D-DR4)',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(
            matterId: 'm-9',
            matters: <String, dynamic>{'title': 'Lease review'},
          ),
        ];

        final Document document =
            (await gateway.fetchDocuments()).valueOrNull!.single;

        expect(document.matterRef, 'Lease review');
      },
    );

    test(
      'falls back to the raw matter id when the embed is absent (D-DR4)',
      () async {
        api.rows = <Map<String, dynamic>>[_row(matters: null)];

        final Document document =
            (await gateway.fetchDocuments()).valueOrNull!.single;

        expect(document.matterRef, 'm-1');
      },
    );

    test(
      'falls back to the raw matter id when the embed title is empty',
      () async {
        api.rows = <Map<String, dynamic>>[
          _row(matters: <String, dynamic>{'title': ''}),
        ];

        final Document document =
            (await gateway.fetchDocuments()).valueOrNull!.single;

        expect(document.matterRef, 'm-1');
      },
    );

    test('parses created_at and converts to local time', () async {
      api.rows = <Map<String, dynamic>>[_row()];

      final Document document =
          (await gateway.fetchDocuments()).valueOrNull!.single;

      expect(
        document.createdAt,
        DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
      );
    });

    test('returns an empty success for no rows', () async {
      final Result<List<Document>> result = await gateway.fetchDocuments();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('loud provider-drift handling', () {
    test('an unknown document_type name fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(documentType: 'tax')];

      final Result<List<Document>> result = await gateway.fetchDocuments();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'document_read_failed');
    });

    test('a missing title fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'doc-1', 'matter_id': 'm-1'},
      ];

      final Result<List<Document>> result = await gateway.fetchDocuments();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'document_read_failed');
    });

    test('a missing matter_id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'doc-1', 'title': 'Demo letter'},
      ];

      final Result<List<Document>> result = await gateway.fetchDocuments();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'document_read_failed');
    });

    test('a missing id fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'matter_id': 'm-1', 'title': 'Demo letter'},
      ];

      final Result<List<Document>> result = await gateway.fetchDocuments();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'document_read_failed');
    });
  });

  group('failure mapping (contract §5)', () {
    test('maps a denied read to the denied AppError code', () async {
      api.error = const SupabaseDocumentException(
        kind: SupabaseDocumentFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<Document>> result = await gateway.fetchDocuments();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'document_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseDocumentException(
          kind: SupabaseDocumentFailureKind.unknown,
          message: 'provider hiccup',
        );

        final Result<List<Document>> result = await gateway.fetchDocuments();

        final AppError error = result.errorOrNull!;
        expect(error.code, 'document_read_failed');
        // The failure path never touches row content (the seam throws before
        // mapping runs) and the AppError context stays empty by construction
        // — only the provider's own message crosses as the technical message.
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.context, isEmpty);
      },
    );
  });
}
