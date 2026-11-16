import 'package:equatable/equatable.dart';

/// One saved article (ADR-0010).
///
/// Joins the article and document titles the saved list needs, so the screen
/// renders a row without a second read. [isSample] is inherited from either side
/// of the join: a bookmark on an invented article must still be badged.
class LegalBookmark extends Equatable {
  const LegalBookmark({
    required this.id,
    required this.articleId,
    required this.documentId,
    required this.documentTitleAr,
    required this.articleNumber,
    required this.articleSample,
    required this.documentSample,
    required this.createdAt,
    this.headingAr,
    this.note,
  });

  final String id;
  final String articleId;
  final String documentId;
  final String documentTitleAr;
  final String articleNumber;
  final String? headingAr;

  /// The reader's optional note, captured when the bookmark was created.
  final String? note;

  final bool articleSample;
  final bool documentSample;
  final DateTime createdAt;

  bool get isSample => articleSample || documentSample;

  @override
  List<Object?> get props => <Object?>[
    id,
    articleId,
    documentId,
    documentTitleAr,
    articleNumber,
    headingAr,
    note,
    articleSample,
    documentSample,
    createdAt,
  ];
}
