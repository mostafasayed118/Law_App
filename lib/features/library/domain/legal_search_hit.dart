import 'package:equatable/equatable.dart';

import 'package:legalhub/features/library/domain/legal_enums.dart';

/// One search result: an ARTICLE hit, carrying just enough document context to
/// render a row and navigate (ADR-0009).
///
/// Article-level rather than document-level on purpose: a query for a phrase
/// should land the reader on the article that contains it, not on the front
/// page of a 400-article code. [snippet] is a server-produced excerpt with the
/// matched spans wrapped in `[[` / `]]` so presentation can highlight without
/// re-running the match.
class LegalSearchHit extends Equatable {
  const LegalSearchHit({
    required this.articleId,
    required this.documentId,
    required this.documentTitleAr,
    required this.category,
    required this.status,
    required this.articleNumber,
    required this.snippet,
    required this.articleSample,
    required this.documentSample,
    this.documentTitleEn,
    this.officialNumber,
    this.year,
    this.headingAr,
  });

  final String articleId;
  final String documentId;
  final String documentTitleAr;
  final String? documentTitleEn;
  final String? officialNumber;
  final int? year;
  final LegalCategory category;
  final LegalStatus status;
  final String articleNumber;
  final String? headingAr;

  /// Excerpt with `[[` / `]]` delimiters around matched spans.
  final String snippet;

  final bool articleSample;
  final bool documentSample;

  /// True when any part of the hit is invented demonstration content.
  bool get isSample => articleSample || documentSample;

  @override
  List<Object?> get props => <Object?>[
    articleId,
    documentId,
    documentTitleAr,
    documentTitleEn,
    officialNumber,
    year,
    category,
    status,
    articleNumber,
    headingAr,
    snippet,
    articleSample,
    documentSample,
  ];
}
