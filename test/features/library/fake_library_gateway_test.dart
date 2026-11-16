import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/data/fake_library_gateway.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';

/// The demo gateway is the product posture in an env-less build, so its
/// behaviour is pinned as tightly as the server's: the same three documents,
/// the same six-article shape (including a "5 مكرر" number), and the same
/// search semantics — an Arabic fold plus an article-stripped fallback.
void main() {
  late FakeLibraryGateway gateway;

  setUp(() {
    gateway = FakeLibraryGateway();
  });

  group('corpus posture', () {
    test('every synthetic row is marked sample', () {
      expect(
        FakeLibraryGateway.syntheticDocuments.every(
          (LegalDocument doc) => doc.isSample,
        ),
        isTrue,
      );
      expect(
        FakeLibraryGateway.syntheticArticles.every(
          (article) => article.isSample,
        ),
        isTrue,
      );
    });

    test('synthetic ids are never mistaken for uuids', () {
      expect(FakeLibraryGateway.syntheticDocuments.first.hasRealId, isFalse);
      expect(FakeLibraryGateway.syntheticArticles.first.hasRealId, isFalse);
    });

    test('the corpus covers three categories', () {
      expect(
        FakeLibraryGateway.syntheticDocuments
            .map((LegalDocument doc) => doc.category)
            .toSet(),
        <LegalCategory>{
          LegalCategory.civil,
          LegalCategory.labor,
          LegalCategory.commercial,
        },
      );
    });
  });

  group('listDocuments', () {
    test('returns every document newest publication first', () async {
      final Result<List<LegalDocument>> result = await gateway.listDocuments();
      expect(result, isA<Success<List<LegalDocument>>>());
      final List<LegalDocument> rows =
          (result as Success<List<LegalDocument>>).value;
      expect(rows, hasLength(3));
      expect(rows.map((LegalDocument doc) => doc.year).toList(), <int>[
        2021,
        2020,
        2019,
      ]);
    });

    test('filters by category', () async {
      final Result<List<LegalDocument>> result = await gateway.listDocuments(
        category: LegalCategory.labor,
      );
      final List<LegalDocument> rows =
          (result as Success<List<LegalDocument>>).value;
      expect(rows, hasLength(1));
      expect(rows.single.category, LegalCategory.labor);
    });

    test('clamps a zero limit up to one row', () async {
      final Result<List<LegalDocument>> result = await gateway.listDocuments(
        limit: 0,
      );
      expect((result as Success<List<LegalDocument>>).value, hasLength(1));
    });

    test('an offset past the end is an empty success, not a failure', () async {
      final Result<List<LegalDocument>> result = await gateway.listDocuments(
        offset: 99,
      );
      expect((result as Success<List<LegalDocument>>).value, isEmpty);
    });
  });

  group('getDocument', () {
    test('returns the articles in ordinal order, including "5 مكرر"', () async {
      final Result<LegalDocumentDetail> result = await gateway.getDocument(
        'legal-doc-1',
      );
      final LegalDocumentDetail detail =
          (result as Success<LegalDocumentDetail>).value;
      expect(detail.articles, hasLength(6));
      expect(detail.articleTotal, 6);
      expect(detail.isTruncated, isFalse);
      expect(detail.articles.map((article) => article.ordinal).toList(), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(detail.articles.last.articleNumber, '5 مكرر');
      expect(detail.document.isSample, isTrue);
    });

    test('an unknown id is a typed not-found failure', () async {
      final Result<LegalDocumentDetail> result = await gateway.getDocument(
        'legal-doc-missing',
      );
      expect(result, isA<Failure<LegalDocumentDetail>>());
      expect(
        (result as Failure<LegalDocumentDetail>).error.code,
        LibraryErrors.documentNotFoundCode,
      );
    });
  });

  group('getArticle', () {
    test('exposes the neighbours of a middle article', () async {
      final Result<LegalArticleDetail> result = await gateway.getArticle(
        'legal-art-1-3',
      );
      final LegalArticleDetail detail =
          (result as Success<LegalArticleDetail>).value;
      expect(detail.previousArticleId, 'legal-art-1-2');
      expect(detail.nextArticleId, 'legal-art-1-4');
      expect(detail.articleTotal, 6);
      expect(detail.documentTitleAr, contains('للإيجارات'));
    });

    test(
      'the first article has no predecessor and the last no successor',
      () async {
        final LegalArticleDetail first =
            ((await gateway.getArticle('legal-art-1-1'))
                    as Success<LegalArticleDetail>)
                .value;
        expect(first.previousArticleId, isNull);
        expect(first.nextArticleId, 'legal-art-1-2');

        final LegalArticleDetail last =
            ((await gateway.getArticle('legal-art-1-6'))
                    as Success<LegalArticleDetail>)
                .value;
        expect(last.previousArticleId, 'legal-art-1-5');
        expect(last.nextArticleId, isNull);
      },
    );

    test('an unknown id is a typed not-found failure', () async {
      final Result<LegalArticleDetail> result = await gateway.getArticle(
        'legal-art-missing',
      );
      expect(
        (result as Failure<LegalArticleDetail>).error.code,
        LibraryErrors.articleNotFoundCode,
      );
    });
  });

  group('search', () {
    Future<List<LegalSearchHit>> hits(String query) async {
      final Result<List<LegalSearchHit>> result = await gateway.search(
        query: query,
      );
      return (result as Success<List<LegalSearchHit>>).value;
    }

    test('a bare-alef query reaches the hamza spelling', () async {
      expect(await hits('الايجار'), isNotEmpty);
    });

    test('a diacritised query matches the plain body', () async {
      expect(await hits('الإيجَار'), isNotEmpty);
    });

    test(
      'a query without the Arabic article reaches the article form',
      () async {
        expect(await hits('ايجار'), isNotEmpty);
      },
    );

    test('all three spellings return the same article ids', () async {
      final List<String> withArticle = (await hits(
        'الإيجار',
      )).map((LegalSearchHit hit) => hit.articleId).toList();
      final List<String> bare = (await hits(
        'ايجار',
      )).map((LegalSearchHit hit) => hit.articleId).toList();
      expect(bare, containsAll(withArticle));
    });

    test('an unknown term returns no hits', () async {
      expect(await hits('zzzznonexistentterm'), isEmpty);
    });

    test('an empty query is an empty success, not a failure', () async {
      final Result<List<LegalSearchHit>> result = await gateway.search(
        query: '   ',
      );
      expect(result, isA<Success<List<LegalSearchHit>>>());
      expect((result as Success<List<LegalSearchHit>>).value, isEmpty);
    });

    test('a punctuation-only query returns no hits', () async {
      final Result<List<LegalSearchHit>> result = await gateway.search(
        query: '!!!',
      );
      expect((result as Success<List<LegalSearchHit>>).value, isEmpty);
    });

    test('a query over 200 characters is rejected', () async {
      final Result<List<LegalSearchHit>> result = await gateway.search(
        query: 'ا' * 201,
      );
      expect(
        (result as Failure<List<LegalSearchHit>>).error.code,
        LibraryErrors.queryTooLongCode,
      );
    });

    test('the category filter narrows the hits', () async {
      final Result<List<LegalSearchHit>> result = await gateway.search(
        query: 'العمل',
        category: LegalCategory.labor,
      );
      final List<LegalSearchHit> rows =
          (result as Success<List<LegalSearchHit>>).value;
      expect(rows, isNotEmpty);
      expect(
        rows.every((LegalSearchHit hit) => hit.category == LegalCategory.labor),
        isTrue,
      );
    });

    test('hits carry the sample flag from either side of the join', () async {
      final List<LegalSearchHit> rows = await hits('ايجار');
      expect(rows, isNotEmpty);
      expect(rows.every((LegalSearchHit hit) => hit.isSample), isTrue);
    });

    test('a larger limit never exceeds the server cap', () async {
      final List<LegalSearchHit> rows = await hits('النموذج');
      expect(rows.length, lessThanOrEqualTo(FakeLibraryGateway.maxLimit));
    });
  });
}
