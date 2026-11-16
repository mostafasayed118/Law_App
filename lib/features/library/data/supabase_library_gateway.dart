import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/library/supabase_library_api.dart';
import 'package:legalhub/data/row_reader.dart';
import 'package:legalhub/features/library/domain/legal_article.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';

/// Legal Library backed by the Supabase provider (ADR-0009).
///
/// Domain mapping happens here (contract §5 pattern): raw RPC rows become
/// entities, the snake_case schema enums become Dart enums, and typed
/// [SupabaseLibraryException]s become [AppError]s with the denied/unavailable
/// classification preserved so the UI can tell "you may not" from "try again".
///
/// The wire values are pinned in one place per enum. A schema value the app
/// does not know fails as drift ([FormatException] → `unknown`), never as a
/// silently wrong label.
class SupabaseLibraryGateway implements LibraryGateway {
  SupabaseLibraryGateway(this._api);

  final SupabaseLibraryApi _api;

  static const Map<String, LegalCategory> _categories = <String, LegalCategory>{
    'civil': LegalCategory.civil,
    'criminal': LegalCategory.criminal,
    'labor': LegalCategory.labor,
    'commercial': LegalCategory.commercial,
    'family': LegalCategory.family,
    'administrative': LegalCategory.administrative,
    'constitutional': LegalCategory.constitutional,
    'other': LegalCategory.other,
  };

  static const Map<String, LegalStatus> _statuses = <String, LegalStatus>{
    'in_force': LegalStatus.inForce,
    'amended': LegalStatus.amended,
    'repealed': LegalStatus.repealed,
    'unknown': LegalStatus.unknown,
  };

  static const Map<String, LegalSourceKind> _kinds = <String, LegalSourceKind>{
    'statute': LegalSourceKind.statute,
    'regulation': LegalSourceKind.regulation,
    'court_ruling': LegalSourceKind.courtRuling,
  };

  static const Map<LegalCategory, String> _categoryWire =
      <LegalCategory, String>{
        LegalCategory.civil: 'civil',
        LegalCategory.criminal: 'criminal',
        LegalCategory.labor: 'labor',
        LegalCategory.commercial: 'commercial',
        LegalCategory.family: 'family',
        LegalCategory.administrative: 'administrative',
        LegalCategory.constitutional: 'constitutional',
        LegalCategory.other: 'other',
      };

  @override
  Future<Result<List<LegalDocument>>> listDocuments({
    LegalCategory? category,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.listDocuments(
        category: category == null ? null : _categoryWire[category],
        limit: limit,
        offset: offset,
      );
      return Result<List<LegalDocument>>.success(
        List<LegalDocument>.unmodifiable(rows.map(_documentFromRow)),
      );
    } on SupabaseLibraryException catch (e) {
      return Result<List<LegalDocument>>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<List<LegalDocument>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<LegalDocumentDetail>> getDocument(String id) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.getDocument(id);
      if (rows.isEmpty) {
        return const Result<LegalDocumentDetail>.failure(
          LibraryErrors.documentNotFound,
        );
      }
      final Map<String, dynamic> header = rows.first;
      final List<LegalArticle> articles = <LegalArticle>[];
      for (final Map<String, dynamic> row in rows) {
        final String? articleId = optionalString(row['article_id']);
        if (articleId == null) {
          // A document with no articles comes back as a single header row
          // with every article column null.
          continue;
        }
        articles.add(_articleFromRow(row, documentId: header['document_id']));
      }
      final int total =
          _intOrNull(rows.first['article_total']) ?? articles.length;
      return Result<LegalDocumentDetail>.success(
        LegalDocumentDetail(
          document: _documentFromRow(header, idKey: 'document_id'),
          articles: List<LegalArticle>.unmodifiable(articles),
          articleTotal: total,
        ),
      );
    } on SupabaseLibraryException catch (e) {
      return Result<LegalDocumentDetail>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<LegalDocumentDetail>.failure(_drift(e));
    }
  }

  @override
  Future<Result<LegalArticleDetail>> getArticle(String id) async {
    try {
      final List<Map<String, dynamic>> rows = await _api.getArticle(id);
      if (rows.isEmpty) {
        return const Result<LegalArticleDetail>.failure(
          LibraryErrors.articleNotFound,
        );
      }
      final Map<String, dynamic> row = rows.first;
      return Result<LegalArticleDetail>.success(
        LegalArticleDetail(
          article: _articleFromRow(row, documentId: row['document_id']),
          documentTitleAr: requiredString(row, 'document_title_ar'),
          documentTitleEn: optionalString(row['document_title_en']),
          documentSample: row['document_sample'] == true,
          articleTotal: _intOrNull(row['article_total']) ?? 1,
          previousArticleId: optionalString(row['prev_article_id']),
          nextArticleId: optionalString(row['next_article_id']),
        ),
      );
    } on SupabaseLibraryException catch (e) {
      return Result<LegalArticleDetail>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<LegalArticleDetail>.failure(_drift(e));
    }
  }

  @override
  Future<Result<List<LegalSearchHit>>> search({
    required String query,
    LegalCategory? category,
    int limit = 20,
    int offset = 0,
  }) async {
    if (query.trim().isEmpty) {
      return const Result<List<LegalSearchHit>>.success(<LegalSearchHit>[]);
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.search(
        query: query,
        category: category == null ? null : _categoryWire[category],
        limit: limit,
        offset: offset,
      );
      return Result<List<LegalSearchHit>>.success(
        List<LegalSearchHit>.unmodifiable(rows.map(_hitFromRow)),
      );
    } on SupabaseLibraryException catch (e) {
      return Result<List<LegalSearchHit>>.failure(_errorFor(e));
    } on FormatException catch (e) {
      return Result<List<LegalSearchHit>>.failure(_drift(e));
    }
  }

  // --- row mapping ---------------------------------------------------------

  LegalDocument _documentFromRow(
    Map<String, dynamic> row, {
    String idKey = 'id',
  }) {
    return LegalDocument(
      id: requiredString(row, idKey),
      sourceId: requiredString(row, 'source_id'),
      sourceNameAr: requiredString(row, 'source_name_ar'),
      sourceKind: _wireKind(row['source_kind']),
      titleAr: requiredString(row, 'title_ar'),
      titleEn: optionalString(row['title_en']),
      officialNumber: optionalString(row['official_number']),
      year: _intOrNull(row['year']),
      category: _wireCategory(row['category']),
      status: _wireStatus(row['status']),
      summaryAr: optionalString(row['summary_ar']),
      publishedAt: optionalDate(row['published_at']),
      isSample: row['is_sample'] == true,
      articleCount: _intOrNull(row['article_count']) ?? 0,
    );
  }

  LegalArticle _articleFromRow(
    Map<String, dynamic> row, {
    required Object? documentId,
  }) {
    final String? resolvedDocumentId = optionalString(documentId);
    return LegalArticle(
      id: requiredString(row, 'article_id'),
      documentId: resolvedDocumentId ?? requiredString(row, 'document_id'),
      articleNumber: requiredString(row, 'article_number'),
      ordinal: _intOrNull(row['ordinal']) ?? 1,
      headingAr: optionalString(row['heading_ar']),
      bodyAr: requiredString(row, 'body_ar', allowWhitespaceOnly: true),
      bodyEn: optionalString(row['body_en']),
      isSample: row['article_sample'] == true || row['is_sample'] == true,
    );
  }

  LegalSearchHit _hitFromRow(Map<String, dynamic> row) {
    return LegalSearchHit(
      articleId: requiredString(row, 'article_id'),
      documentId: requiredString(row, 'document_id'),
      documentTitleAr: requiredString(row, 'document_title_ar'),
      documentTitleEn: optionalString(row['document_title_en']),
      officialNumber: optionalString(row['official_number']),
      year: _intOrNull(row['year']),
      category: _wireCategory(row['category']),
      status: _wireStatus(row['status']),
      articleNumber: requiredString(row, 'article_number'),
      headingAr: optionalString(row['heading_ar']),
      snippet: optionalString(row['snippet']) ?? '',
      articleSample: row['article_sample'] == true,
      documentSample: row['document_sample'] == true,
    );
  }

  LegalCategory _wireCategory(Object? value) {
    final LegalCategory? category = _categories[value];
    if (category == null) {
      throw FormatException('Unknown legal category: $value');
    }
    return category;
  }

  LegalStatus _wireStatus(Object? value) {
    final LegalStatus? status = _statuses[value];
    if (status == null) {
      throw FormatException('Unknown legal status: $value');
    }
    return status;
  }

  LegalSourceKind _wireKind(Object? value) {
    final LegalSourceKind? kind = _kinds[value];
    if (kind == null) {
      throw FormatException('Unknown legal source kind: $value');
    }
    return kind;
  }

  int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // --- failures ------------------------------------------------------------

  AppError _errorFor(SupabaseLibraryException e) {
    switch (e.kind) {
      case SupabaseLibraryFailureKind.denied:
        return AppError(
          code: LibraryErrors.unavailableCode,
          userMessage: 'Unable to load the library. Please try again.',
          messageKey: LibraryErrors.unavailable.messageKey,
          technicalMessage: e.message,
          kind: AppErrorKind.denied,
        );
      case SupabaseLibraryFailureKind.validation:
        return AppError(
          code: LibraryErrors.queryTooLongCode,
          userMessage: 'The search query is too long.',
          messageKey: LibraryErrors.queryTooLong.messageKey,
          technicalMessage: e.message,
        );
      case SupabaseLibraryFailureKind.notFound:
        return AppError(
          code: LibraryErrors.documentNotFoundCode,
          userMessage: 'The document was not found.',
          messageKey: LibraryErrors.documentNotFound.messageKey,
          technicalMessage: e.message,
        );
      case SupabaseLibraryFailureKind.providerUnavailable:
      case SupabaseLibraryFailureKind.unknown:
        return AppError(
          code: LibraryErrors.unavailableCode,
          userMessage: 'Unable to load the library. Please try again.',
          messageKey: LibraryErrors.unavailable.messageKey,
          technicalMessage: e.message,
          kind: AppErrorKind.unavailable,
        );
    }
  }

  AppError _drift(FormatException e) => AppError(
    code: LibraryErrors.unavailableCode,
    userMessage: 'Unable to load the library. Please try again.',
    messageKey: LibraryErrors.unavailable.messageKey,
    technicalMessage: e.message,
    kind: AppErrorKind.unavailable,
  );
}
