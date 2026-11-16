import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/legal_article.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_normalizer.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';

/// Development-only Legal Library implementation (ADR-0009).
///
/// Serves the same three invented sample documents as
/// `supabase/seed/legal_library_sample.sql`, so the demo build and a seeded
/// configured build look the same. Every row is `isSample: true` and the text
/// is deliberately artificial — this class is a demonstration surface, never a
/// source of legal content.
///
/// Search is a faithful Dart port of the server's two arms: every query token
/// must prefix-match an indexed token, OR the normalised query must appear as a
/// substring. That is what makes "ايجار", "الإيجار" and "الإيجَار" all reach the
/// same article in the demo build exactly as they do against Postgres.
///
/// Ids use the non-uuid `legal-doc-*` / `legal-art-*` shape so a synthetic row
/// can never be mistaken for a persisted one ([LegalDocument.hasRealId]).
class FakeLibraryGateway implements LibraryGateway {
  /// The fixed synthetic corpus. Mirrors the seed file row for row.
  static final List<LegalDocument> syntheticDocuments = <LegalDocument>[
    LegalDocument(
      id: 'legal-doc-1',
      sourceId: 'legal-src-1',
      sourceNameAr: 'الجريدة التجريبية',
      sourceKind: LegalSourceKind.statute,
      titleAr: 'قانون تجريبي للإيجارات (نموذج)',
      titleEn: 'Sample Lease Law (sample)',
      officialNumber: 'نموذج ١',
      year: 2020,
      category: LegalCategory.civil,
      status: LegalStatus.inForce,
      summaryAr:
          'نموذج توضيحي ينظم العلاقة الإيجارية. النص مصطنع لأغراض العرض التقني.',
      publishedAt: DateTime.utc(2020, 1, 15),
      isSample: true,
      articleCount: 6,
    ),
    LegalDocument(
      id: 'legal-doc-2',
      sourceId: 'legal-src-1',
      sourceNameAr: 'الجريدة التجريبية',
      sourceKind: LegalSourceKind.statute,
      titleAr: 'لائحة تجريبية لعلاقات العمل (نموذج)',
      titleEn: 'Sample Labour Regulation (sample)',
      officialNumber: 'نموذج ٢',
      year: 2021,
      category: LegalCategory.labor,
      status: LegalStatus.amended,
      summaryAr:
          'نموذج توضيحي ينظم علاقة العمل. النص مصطنع لأغراض العرض التقني.',
      publishedAt: DateTime.utc(2021, 6, 1),
      isSample: true,
      articleCount: 6,
    ),
    LegalDocument(
      id: 'legal-doc-3',
      sourceId: 'legal-src-1',
      sourceNameAr: 'الجريدة التجريبية',
      sourceKind: LegalSourceKind.regulation,
      titleAr: 'تنظيم تجريبي للسجل التجاري (نموذج)',
      titleEn: 'Sample Commercial Registry Rules (sample)',
      officialNumber: 'نموذج ٣',
      year: 2019,
      category: LegalCategory.commercial,
      status: LegalStatus.inForce,
      summaryAr:
          'نموذج توضيحي ينظم قيد المنشآت. النص مصطنع لأغراض العرض التقني.',
      publishedAt: DateTime.utc(2019, 9, 20),
      isSample: true,
      articleCount: 6,
    ),
  ];

  /// The fixed synthetic article corpus, in document/ordinal order.
  static const List<LegalArticle> syntheticArticles = <LegalArticle>[
    // Document 1 — civil / lease.
    LegalArticle(
      id: 'legal-art-1-1',
      documentId: 'legal-doc-1',
      articleNumber: '1',
      ordinal: 1,
      headingAr: 'نطاق التطبيق',
      bodyAr:
          'ينظم هذا النموذج العلاقة الإيجارية بين المؤجر والمستأجر من حيث المدة والأجرة.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-1-2',
      documentId: 'legal-doc-1',
      articleNumber: '2',
      ordinal: 2,
      headingAr: 'شكل العقد',
      bodyAr:
          'يجب أن يكون عقد الإيجار مكتوباً، وأن يحدد بوضوح محل العين المؤجرة والغرض من الاستعمال.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-1-3',
      documentId: 'legal-doc-1',
      articleNumber: '3',
      ordinal: 3,
      headingAr: 'الأجرة',
      bodyAr:
          'تحدد الأجرة في العقد، ويجوز الاتفاق على مراجعتها سنوياً بنسبة متفق عليها.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-1-4',
      documentId: 'legal-doc-1',
      articleNumber: '4',
      ordinal: 4,
      headingAr: 'التزامات المؤجر',
      bodyAr:
          'يلتزم المؤجر بتسليم العين المؤجرة في حالة صالحة للاستعمال المتفق عليه.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-1-5',
      documentId: 'legal-doc-1',
      articleNumber: '5',
      ordinal: 5,
      headingAr: 'التزامات المستأجر',
      bodyAr:
          'يلتزم المستأجر بالمحافظة على العين المؤجرة وعدم تغيير استعمالها دون موافقة كتابية.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-1-6',
      documentId: 'legal-doc-1',
      articleNumber: '5 مكرر',
      ordinal: 6,
      headingAr: 'الإنهاء المبكر',
      bodyAr:
          'يجوز للطرفين إنهاء العقد قبل انتهاء مدته بموجب إخطار كتابي قبل ثلاثين يوماً.',
      isSample: true,
    ),

    // Document 2 — labour.
    LegalArticle(
      id: 'legal-art-2-1',
      documentId: 'legal-doc-2',
      articleNumber: '1',
      ordinal: 1,
      headingAr: 'نطاق التطبيق',
      bodyAr:
          'ينظم هذا النموذج علاقة العمل بين صاحب العمل والعامل، ويحدد الحقوق والالتزامات المتبادلة.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-2-2',
      documentId: 'legal-doc-2',
      articleNumber: '2',
      ordinal: 2,
      headingAr: 'العقد',
      bodyAr:
          'يُبرم عقد العمل كتابةً، ويشمل المسمى الوظيفي والأجر ومدة التجربة إن وجدت.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-2-3',
      documentId: 'legal-doc-2',
      articleNumber: '3',
      ordinal: 3,
      headingAr: 'مدة التجربة',
      bodyAr: 'لا يجوز أن تتجاوز مدة التجربة الحد المتفق عليه في هذا النموذج.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-2-4',
      documentId: 'legal-doc-2',
      articleNumber: '4',
      ordinal: 4,
      headingAr: 'الأجر',
      bodyAr:
          'يستحق العامل أجره في المواعيد المتفق عليها، ولا يجوز خصم أي مبلغ دون سبب مكتوب.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-2-5',
      documentId: 'legal-doc-2',
      articleNumber: '5',
      ordinal: 5,
      headingAr: 'ساعات العمل',
      bodyAr:
          'تكون ساعات العمل موزعة على أيام الأسبوع بما لا يخل بفترات الراحة.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-2-6',
      documentId: 'legal-doc-2',
      articleNumber: '6',
      ordinal: 6,
      headingAr: 'انتهاء العقد',
      bodyAr:
          'ينتهي عقد العمل بانقضاء مدته أو باتفاق الطرفين أو وفقاً للإجراءات المقررة.',
      isSample: true,
    ),

    // Document 3 — commercial.
    LegalArticle(
      id: 'legal-art-3-1',
      documentId: 'legal-doc-3',
      articleNumber: '1',
      ordinal: 1,
      headingAr: 'نطاق التطبيق',
      bodyAr: 'ينظم هذا النموذج قيد المنشآت في السجل التجاري وتحديث بياناتها.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-3-2',
      documentId: 'legal-doc-3',
      articleNumber: '2',
      ordinal: 2,
      headingAr: 'بيانات الطلب',
      bodyAr:
          'يجب أن يتضمن طلب القيد اسم المنشأة ونشاطها وعنوانها وبيانات مالكها.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-3-3',
      documentId: 'legal-doc-3',
      articleNumber: '3',
      ordinal: 3,
      headingAr: 'تحديث البيانات',
      bodyAr:
          'تلتزم المنشأة بإبلاغ الجهة المختصة بأي تغيير في بياناتها خلال المدة المحددة.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-3-4',
      documentId: 'legal-doc-3',
      articleNumber: '4',
      ordinal: 4,
      headingAr: 'رقم القيد',
      bodyAr: 'يصدر لكل منشأة رقم قيد فريد يُستخدم في جميع تعاملاتها الرسمية.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-3-5',
      documentId: 'legal-doc-3',
      articleNumber: '5',
      ordinal: 5,
      headingAr: 'الشطب',
      bodyAr:
          'يجوز شطب القيد بناءً على طلب المالك أو وفقاً للحالات المنصوص عليها في هذا النموذج.',
      isSample: true,
    ),
    LegalArticle(
      id: 'legal-art-3-6',
      documentId: 'legal-doc-3',
      articleNumber: '6',
      ordinal: 6,
      headingAr: 'الرقابة',
      bodyAr: 'تخضع المنشأة للرقابة الدورية للتحقق من مطابقة بياناتها للواقع.',
      isSample: true,
    ),
  ];

  /// The server's hard cap on any single read.
  static const int maxLimit = 50;

  /// The server's cap on the article list inside a document read.
  static const int maxArticlesPerDocument = 200;

  @override
  Future<Result<List<LegalDocument>>> listDocuments({
    LegalCategory? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final List<LegalDocument> rows =
        syntheticDocuments
            .where(
              (LegalDocument doc) =>
                  category == null || doc.category == category,
            )
            .toList(growable: false)
          ..sort(_byRecency);
    return Result<List<LegalDocument>>.success(
      List<LegalDocument>.unmodifiable(
        _page(rows, limit: limit, offset: offset),
      ),
    );
  }

  @override
  Future<Result<LegalDocumentDetail>> getDocument(String id) async {
    final LegalDocument? document = _documentById(id);
    if (document == null) {
      return const Result<LegalDocumentDetail>.failure(
        LibraryErrors.documentNotFound,
      );
    }
    final List<LegalArticle> articles =
        syntheticArticles
            .where((LegalArticle article) => article.documentId == id)
            .toList(growable: false)
          ..sort(
            (LegalArticle a, LegalArticle b) => a.ordinal.compareTo(b.ordinal),
          );
    return Result<LegalDocumentDetail>.success(
      LegalDocumentDetail(
        document: document,
        articles: List<LegalArticle>.unmodifiable(
          articles.take(maxArticlesPerDocument),
        ),
        articleTotal: articles.length,
      ),
    );
  }

  @override
  Future<Result<LegalArticleDetail>> getArticle(String id) async {
    final int index = syntheticArticles.indexWhere(
      (LegalArticle article) => article.id == id,
    );
    if (index < 0) {
      return const Result<LegalArticleDetail>.failure(
        LibraryErrors.articleNotFound,
      );
    }
    final LegalArticle article = syntheticArticles[index];
    final LegalDocument? document = _documentById(article.documentId);
    if (document == null) {
      return const Result<LegalArticleDetail>.failure(
        LibraryErrors.articleNotFound,
      );
    }
    final List<LegalArticle> siblings =
        syntheticArticles
            .where((LegalArticle a) => a.documentId == article.documentId)
            .toList(growable: false)
          ..sort(
            (LegalArticle a, LegalArticle b) => a.ordinal.compareTo(b.ordinal),
          );
    final int position = siblings.indexWhere(
      (LegalArticle a) => a.id == article.id,
    );
    return Result<LegalArticleDetail>.success(
      LegalArticleDetail(
        article: article,
        documentTitleAr: document.titleAr,
        documentTitleEn: document.titleEn,
        documentSample: document.isSample,
        articleTotal: siblings.length,
        previousArticleId: position > 0 ? siblings[position - 1].id : null,
        nextArticleId: position < siblings.length - 1
            ? siblings[position + 1].id
            : null,
      ),
    );
  }

  @override
  Future<Result<List<LegalSearchHit>>> search({
    required String query,
    LegalCategory? category,
    int limit = 20,
    int offset = 0,
  }) async {
    // Mirrors the server contract: an empty query is a successful empty
    // result, not a failure, so the surface can render "nothing asked yet".
    if (query.trim().isEmpty) {
      return const Result<List<LegalSearchHit>>.success(<LegalSearchHit>[]);
    }
    if (query.length > 200) {
      return const Result<List<LegalSearchHit>>.failure(
        LibraryErrors.queryTooLong,
      );
    }

    final List<String> tokens = searchTokens(query);
    if (tokens.isEmpty) {
      return const Result<List<LegalSearchHit>>.success(<LegalSearchHit>[]);
    }
    final String normalizedQuery = normalizeArabic(query);

    final List<({LegalSearchHit hit, int score})> scored =
        <({LegalSearchHit hit, int score})>[];
    for (final LegalArticle article in syntheticArticles) {
      final LegalDocument? document = _documentById(article.documentId);
      if (document == null) {
        continue;
      }
      if (category != null && document.category != category) {
        continue;
      }
      final String haystack = legalSearchText(
        '${document.titleAr} ${document.titleEn ?? ''} '
        '${article.articleNumber} ${article.headingAr ?? ''} ${article.bodyAr}',
      );
      final int score = _matchScore(
        tokens: tokens,
        normalizedQuery: normalizedQuery,
        haystack: haystack,
      );
      if (score == 0) {
        continue;
      }
      scored.add((
        hit: LegalSearchHit(
          articleId: article.id,
          documentId: document.id,
          documentTitleAr: document.titleAr,
          documentTitleEn: document.titleEn,
          officialNumber: document.officialNumber,
          year: document.year,
          category: document.category,
          status: document.status,
          articleNumber: article.articleNumber,
          headingAr: article.headingAr,
          snippet: article.bodyAr,
          articleSample: article.isSample,
          documentSample: document.isSample,
        ),
        score: score,
      ));
    }

    scored.sort((
      ({LegalSearchHit hit, int score}) a,
      ({LegalSearchHit hit, int score}) b,
    ) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final int byTitle = a.hit.documentTitleAr.compareTo(
        b.hit.documentTitleAr,
      );
      if (byTitle != 0) {
        return byTitle;
      }
      return a.hit.articleId.compareTo(b.hit.articleId);
    });

    final List<LegalSearchHit> hits = scored
        .map((({LegalSearchHit hit, int score}) row) => row.hit)
        .toList(growable: false);
    return Result<List<LegalSearchHit>>.success(
      List<LegalSearchHit>.unmodifiable(
        _page(hits, limit: limit, offset: offset),
      ),
    );
  }

  /// Returns 0 for "no match", otherwise a score that ranks exact token
  /// matches above substring-only matches — the same ordering intent as
  /// `ts_rank_cd` plus the server's substring bonus.
  int _matchScore({
    required List<String> tokens,
    required String normalizedQuery,
    required String haystack,
  }) {
    final List<String> haystackTokens = haystack
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);

    int matched = 0;
    for (final String token in tokens) {
      if (haystackTokens.any(
        (String candidate) => candidate.startsWith(token),
      )) {
        matched++;
      }
    }
    final bool allTokensMatch = matched == tokens.length;
    final bool substringMatch = haystack.contains(normalizedQuery);

    if (!allTokensMatch && !substringMatch) {
      return 0;
    }
    return matched * 10 + (substringMatch ? 1 : 0);
  }

  List<T> _page<T>(List<T> rows, {required int limit, required int offset}) {
    final int safeLimit = limit.clamp(1, maxLimit);
    final int safeOffset = offset < 0 ? 0 : offset;
    if (safeOffset >= rows.length) {
      return <T>[];
    }
    return rows.sublist(
      safeOffset,
      (safeOffset + safeLimit).clamp(0, rows.length),
    );
  }

  LegalDocument? _documentById(String id) {
    for (final LegalDocument document in syntheticDocuments) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  static int _byRecency(LegalDocument a, LegalDocument b) {
    final int? yearA = a.year;
    final int? yearB = b.year;
    if (yearA != yearB) {
      if (yearA == null) {
        return 1;
      }
      if (yearB == null) {
        return -1;
      }
      return yearB.compareTo(yearA);
    }
    return a.titleAr.compareTo(b.titleAr);
  }
}
