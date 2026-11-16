import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/library/supabase_library_api.dart';
import 'package:legalhub/features/library/data/supabase_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';

/// Row → domain mapping for the Supabase adapter. The rows below are shaped
/// exactly like the RPC result columns in migration 32, so a column rename in
/// SQL fails here rather than on a device.
void main() {
  Map<String, dynamic> documentRow({
    String id = '11111111-1111-4111-8111-111111111111',
    String category = 'civil',
    String status = 'in_force',
    String kind = 'statute',
  }) {
    return <String, dynamic>{
      'id': id,
      'source_id': '22222222-2222-4222-8222-222222222222',
      'source_name_ar': 'مصدر',
      'source_kind': kind,
      'title_ar': 'عنوان',
      'title_en': 'Title',
      'official_number': '1',
      'year': 2020,
      'category': category,
      'status': status,
      'summary_ar': 'ملخص',
      'published_at': '2020-01-15',
      'is_sample': true,
      'article_count': 2,
    };
  }

  group('listDocuments', () {
    test('maps rows and passes the wire category', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        documents: <Map<String, dynamic>>[documentRow()],
      );
      final SupabaseLibraryGateway gateway = SupabaseLibraryGateway(api);

      final Result<List<LegalDocument>> result = await gateway.listDocuments(
        category: LegalCategory.labor,
      );

      expect(api.lastListCategory, 'labor');
      final LegalDocument document =
          (result as Success<List<LegalDocument>>).value.single;
      expect(document.titleAr, 'عنوان');
      expect(document.category, LegalCategory.civil);
      expect(document.status, LegalStatus.inForce);
      expect(document.sourceKind, LegalSourceKind.statute);
      expect(document.isSample, isTrue);
      expect(document.publishedAt, DateTime(2020, 1, 15));
      expect(document.hasRealId, isTrue);
    });

    test('an unknown schema enum is drift, not a wrong label', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        documents: <Map<String, dynamic>>[documentRow(category: 'space_law')],
      );
      final Result<List<LegalDocument>> result = await SupabaseLibraryGateway(
        api,
      ).listDocuments();

      final AppError error = (result as Failure<List<LegalDocument>>).error;
      expect(error.code, LibraryErrors.unavailableCode);
      expect(error.kind, AppErrorKind.unavailable);
    });

    test(
      'a denied call keeps the denied kind so the UI does not retry',
      () async {
        final _StubLibraryApi api = _StubLibraryApi(
          failure: const SupabaseLibraryException(
            kind: SupabaseLibraryFailureKind.denied,
            message: 'permission denied',
          ),
        );
        final Result<List<LegalDocument>> result = await SupabaseLibraryGateway(
          api,
        ).listDocuments();

        expect(
          (result as Failure<List<LegalDocument>>).error.kind,
          AppErrorKind.denied,
        );
      },
    );
  });

  group('getDocument', () {
    test('an empty result is a typed not-found', () async {
      final Result<LegalDocumentDetail> result = await SupabaseLibraryGateway(
        _StubLibraryApi(),
      ).getDocument('x');

      expect(
        (result as Failure<LegalDocumentDetail>).error.code,
        LibraryErrors.documentNotFoundCode,
      );
    });

    test('maps the header and its ordered articles', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        documentRows: <Map<String, dynamic>>[
          <String, dynamic>{
            ...documentRow(),
            'document_id': '11111111-1111-4111-8111-111111111111',
            'document_sample': true,
            'article_total': 2,
            'article_id': '33333333-3333-4333-8333-333333333331',
            'article_number': '1',
            'ordinal': 1,
            'heading_ar': 'عنوان المادة',
            'body_ar': 'نص المادة الأول',
            'body_en': null,
            'article_sample': true,
          },
          <String, dynamic>{
            ...documentRow(),
            'document_id': '11111111-1111-4111-8111-111111111111',
            'document_sample': true,
            'article_total': 2,
            'article_id': '33333333-3333-4333-8333-333333333332',
            'article_number': '5 مكرر',
            'ordinal': 2,
            'heading_ar': null,
            'body_ar': 'نص المادة الثانية',
            'body_en': null,
            'article_sample': true,
          },
        ],
      );
      final Result<LegalDocumentDetail> result = await SupabaseLibraryGateway(
        api,
      ).getDocument('doc');

      final LegalDocumentDetail detail =
          (result as Success<LegalDocumentDetail>).value;
      expect(detail.articles, hasLength(2));
      expect(detail.articles.last.articleNumber, '5 مكرر');
      expect(detail.articleTotal, 2);
      expect(detail.isTruncated, isFalse);
      expect(detail.articles.first.documentId, detail.document.id);
    });

    test(
      'a document with no articles is a header with an empty list',
      () async {
        final _StubLibraryApi api = _StubLibraryApi(
          documentRows: <Map<String, dynamic>>[
            <String, dynamic>{
              ...documentRow(),
              'document_id': '11111111-1111-4111-8111-111111111111',
              'article_total': 0,
              'article_id': null,
            },
          ],
        );
        final LegalDocumentDetail detail =
            ((await SupabaseLibraryGateway(api).getDocument('doc'))
                    as Success<LegalDocumentDetail>)
                .value;
        expect(detail.articles, isEmpty);
        expect(detail.articleTotal, 0);
        expect(detail.isTruncated, isFalse);
      },
    );
  });

  group('getArticle', () {
    test('maps neighbours and the document context', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        articleRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_id': '33333333-3333-4333-8333-333333333331',
            'document_id': '11111111-1111-4111-8111-111111111111',
            'article_number': '2',
            'ordinal': 2,
            'heading_ar': null,
            'body_ar': 'نص',
            'body_en': null,
            'article_sample': true,
            'document_title_ar': 'عنوان الوثيقة',
            'document_title_en': 'Document title',
            'document_sample': false,
            'prev_article_id': '33333333-3333-4333-8333-333333333330',
            'next_article_id': null,
            'article_total': 3,
          },
        ],
      );
      final LegalArticleDetail detail =
          ((await SupabaseLibraryGateway(api).getArticle('a'))
                  as Success<LegalArticleDetail>)
              .value;
      expect(detail.documentTitleAr, 'عنوان الوثيقة');
      expect(detail.previousArticleId, '33333333-3333-4333-8333-333333333330');
      expect(detail.nextArticleId, isNull);
      expect(detail.articleTotal, 3);
      // Sample if EITHER side is sample.
      expect(detail.isSample, isTrue);
    });

    test('an empty result is a typed not-found', () async {
      final Result<LegalArticleDetail> result = await SupabaseLibraryGateway(
        _StubLibraryApi(),
      ).getArticle('x');
      expect(
        (result as Failure<LegalArticleDetail>).error.code,
        LibraryErrors.articleNotFoundCode,
      );
    });
  });

  group('search', () {
    test('an empty query never reaches the provider', () async {
      final _StubLibraryApi api = _StubLibraryApi();
      final Result<List<LegalSearchHit>> result = await SupabaseLibraryGateway(
        api,
      ).search(query: '   ');

      expect(api.searchCalls, 0);
      expect((result as Success<List<LegalSearchHit>>).value, isEmpty);
    });

    test('maps hits including the snippet and the sample flags', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        searchRows: <Map<String, dynamic>>[
          <String, dynamic>{
            'article_id': '33333333-3333-4333-8333-333333333331',
            'document_id': '11111111-1111-4111-8111-111111111111',
            'document_title_ar': 'عنوان',
            'document_title_en': null,
            'official_number': '1',
            'year': 2020,
            'category': 'commercial',
            'status': 'amended',
            'article_number': '3',
            'heading_ar': 'الأجرة',
            'snippet': 'نص [[الايجار]] هنا',
            'article_sample': true,
            'document_sample': false,
            'rank': 0.7,
            'total_count': 1,
          },
        ],
      );
      final LegalSearchHit hit =
          ((await SupabaseLibraryGateway(api).search(query: 'ايجار'))
                  as Success<List<LegalSearchHit>>)
              .value
              .single;
      expect(hit.category, LegalCategory.commercial);
      expect(hit.status, LegalStatus.amended);
      expect(hit.snippet, contains('[['));
      expect(hit.isSample, isTrue);
    });

    test('a validation failure maps to the query-too-long error', () async {
      final _StubLibraryApi api = _StubLibraryApi(
        failure: const SupabaseLibraryException(
          kind: SupabaseLibraryFailureKind.validation,
          message: 'legal_search_query_too_long',
        ),
      );
      final Result<List<LegalSearchHit>> result = await SupabaseLibraryGateway(
        api,
      ).search(query: 'x');

      expect(
        (result as Failure<List<LegalSearchHit>>).error.code,
        LibraryErrors.queryTooLongCode,
      );
    });
  });
}

/// Hand-written stub: the gateway is the unit under test, and a mock library
/// would only re-assert that mocktail works.
class _StubLibraryApi implements SupabaseLibraryApi {
  _StubLibraryApi({
    this.documents = const <Map<String, dynamic>>[],
    this.documentRows = const <Map<String, dynamic>>[],
    this.articleRows = const <Map<String, dynamic>>[],
    this.searchRows = const <Map<String, dynamic>>[],
    this.failure,
  });

  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> documentRows;
  final List<Map<String, dynamic>> articleRows;
  final List<Map<String, dynamic>> searchRows;
  final SupabaseLibraryException? failure;

  String? lastListCategory;
  int searchCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> listDocuments({
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    lastListCategory = category;
    if (failure != null) {
      throw failure!;
    }
    return documents;
  }

  @override
  Future<List<Map<String, dynamic>>> getDocument(
    String id, {
    int articleLimit = 200,
  }) async {
    if (failure != null) {
      throw failure!;
    }
    return documentRows;
  }

  @override
  Future<List<Map<String, dynamic>>> getArticle(String id) async {
    if (failure != null) {
      throw failure!;
    }
    return articleRows;
  }

  @override
  Future<List<Map<String, dynamic>>> search({
    required String query,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    searchCalls++;
    if (failure != null) {
      throw failure!;
    }
    return searchRows;
  }
}
