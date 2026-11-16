import 'package:equatable/equatable.dart';

/// One row of the reader's history (ADR-0010).
///
/// Bookkeeping, not an audit: the server keeps only the newest 100 rows per user
/// and prunes on every write, because a history that grows without bound is a
/// liability rather than a feature.
class ReadingHistoryEntry extends Equatable {
  const ReadingHistoryEntry({
    required this.id,
    required this.articleId,
    required this.documentId,
    required this.documentTitleAr,
    required this.articleNumber,
    required this.lastReadAt,
    required this.readCount,
    required this.articleSample,
    required this.documentSample,
    this.headingAr,
  });

  final String id;
  final String articleId;
  final String documentId;
  final String documentTitleAr;
  final String articleNumber;
  final String? headingAr;
  final DateTime lastReadAt;
  final int readCount;
  final bool articleSample;
  final bool documentSample;

  bool get isSample => articleSample || documentSample;

  @override
  List<Object?> get props => <Object?>[
    id,
    articleId,
    documentId,
    documentTitleAr,
    articleNumber,
    headingAr,
    lastReadAt,
    readCount,
    articleSample,
    documentSample,
  ];
}
