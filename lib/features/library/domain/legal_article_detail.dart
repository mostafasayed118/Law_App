import 'package:equatable/equatable.dart';

import 'package:legalhub/features/library/domain/legal_article.dart';

/// One article plus everything the reader needs around it (ADR-0009).
///
/// [previousArticleId] and [nextArticleId] are resolved server-side from the
/// document's ordinal order, so the reader can offer "previous / next" without
/// re-reading the whole document or guessing at neighbours. A first article has
/// no previous; a last article has no next.
class LegalArticleDetail extends Equatable {
  const LegalArticleDetail({
    required this.article,
    required this.documentTitleAr,
    required this.documentSample,
    required this.articleTotal,
    this.documentTitleEn,
    this.previousArticleId,
    this.nextArticleId,
  });

  final LegalArticle article;
  final String documentTitleAr;
  final String? documentTitleEn;

  /// The parent document's own sample flag. The reader shows the badge when
  /// this OR [LegalArticle.isSample] is true.
  final bool documentSample;

  final int articleTotal;
  final String? previousArticleId;
  final String? nextArticleId;

  bool get isSample => article.isSample || documentSample;

  @override
  List<Object?> get props => <Object?>[
    article,
    documentTitleAr,
    documentTitleEn,
    documentSample,
    articleTotal,
    previousArticleId,
    nextArticleId,
  ];
}
