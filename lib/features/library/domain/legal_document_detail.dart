import 'package:equatable/equatable.dart';

import 'package:legalhub/features/library/domain/legal_article.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';

/// A whole document plus its articles, in reading order (ADR-0009).
///
/// The reader needs the header and the article list together, and a single
/// bounded round trip is cheaper than a header read followed by a list read.
/// [articles] is ordered by [LegalArticle.ordinal]; [articleTotal] reports how
/// many the document actually has so a truncated read can say so rather than
/// pretending the list is complete.
class LegalDocumentDetail extends Equatable {
  const LegalDocumentDetail({
    required this.document,
    required this.articles,
    required this.articleTotal,
  });

  final LegalDocument document;
  final List<LegalArticle> articles;
  final int articleTotal;

  /// True when the read was bounded below the document's real article count.
  bool get isTruncated => articles.length < articleTotal;

  @override
  List<Object?> get props => <Object?>[document, articles, articleTotal];
}
