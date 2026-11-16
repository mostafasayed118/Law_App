import 'dart:async';

import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';
import 'package:legalhub/features/library/domain/library_errors.dart';
import 'package:legalhub/features/library/domain/library_gateway.dart';

/// A scriptable [LibraryGateway] for the library cubit tests.
///
/// Returns canned [Result]s, records the calls it received, and can be held
/// open with [gate] so a test can assert what the cubit emits while a read is
/// still in flight — the in-flight guards are exactly what these cubits get
/// wrong when they get anything wrong.
class StubLibraryGateway implements LibraryGateway {
  StubLibraryGateway({
    this.documents = const Success<List<LegalDocument>>(<LegalDocument>[]),
    this.documentDetail,
    this.articleDetail,
    this.hits = const Success<List<LegalSearchHit>>(<LegalSearchHit>[]),
  });

  Result<List<LegalDocument>> documents;
  Result<LegalDocumentDetail>? documentDetail;
  Result<LegalArticleDetail>? articleDetail;
  Result<List<LegalSearchHit>> hits;

  /// When set, every read waits for this completer before returning.
  Completer<void>? gate;

  final List<LegalCategory?> requestedCategories = <LegalCategory?>[];
  final List<String> requestedDocumentIds = <String>[];
  final List<String> requestedArticleIds = <String>[];
  final List<String> requestedQueries = <String>[];
  final List<LegalCategory?> requestedSearchCategories = <LegalCategory?>[];

  Future<void> _wait() async {
    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }

  @override
  Future<Result<List<LegalDocument>>> listDocuments({
    LegalCategory? category,
    int limit = 50,
    int offset = 0,
  }) async {
    requestedCategories.add(category);
    await _wait();
    return documents;
  }

  @override
  Future<Result<LegalDocumentDetail>> getDocument(String id) async {
    requestedDocumentIds.add(id);
    await _wait();
    return documentDetail ??
        const Failure<LegalDocumentDetail>(LibraryErrors.documentNotFound);
  }

  @override
  Future<Result<LegalArticleDetail>> getArticle(String id) async {
    requestedArticleIds.add(id);
    await _wait();
    return articleDetail ??
        const Failure<LegalArticleDetail>(LibraryErrors.articleNotFound);
  }

  @override
  Future<Result<List<LegalSearchHit>>> search({
    required String query,
    LegalCategory? category,
    int limit = 20,
    int offset = 0,
  }) async {
    requestedQueries.add(query);
    requestedSearchCategories.add(category);
    await _wait();
    return hits;
  }
}
