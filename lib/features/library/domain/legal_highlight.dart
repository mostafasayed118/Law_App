import 'package:equatable/equatable.dart';

import 'package:legalhub/features/library/domain/highlight_color_slot.dart';

/// One highlighted range of an article (ADR-0010).
///
/// [startOffset] and [endOffset] are rune offsets, end-exclusive — the same
/// coordinate system the server validates against. [quote] is a snapshot taken
/// when the highlight was created, so a reader can still be shown what they
/// marked even after the article is amended.
///
/// [isStale] is computed server-side by comparing the stored body hash with the
/// article's current one. A stale highlight must never be drawn at its offsets:
/// the words under them may now be different, so the reader shows the quote in a
/// distinct treatment instead.
class LegalHighlight extends Equatable {
  const LegalHighlight({
    required this.id,
    required this.articleId,
    required this.documentId,
    required this.documentTitleAr,
    required this.articleNumber,
    required this.startOffset,
    required this.endOffset,
    required this.quote,
    required this.color,
    required this.isStale,
    required this.articleSample,
    required this.documentSample,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String articleId;
  final String documentId;
  final String documentTitleAr;
  final String articleNumber;

  /// Rune offset of the first highlighted character.
  final int startOffset;

  /// Rune offset one past the last highlighted character.
  final int endOffset;

  final String quote;
  final HighlightColorSlot color;
  final String? note;

  /// True when the article body changed since this highlight was created.
  final bool isStale;

  final bool articleSample;
  final bool documentSample;
  final DateTime createdAt;

  bool get isSample => articleSample || documentSample;

  /// Length of the span in runes.
  int get length => endOffset - startOffset;

  @override
  List<Object?> get props => <Object?>[
    id,
    articleId,
    documentId,
    documentTitleAr,
    articleNumber,
    startOffset,
    endOffset,
    quote,
    color,
    note,
    isStale,
    articleSample,
    documentSample,
    createdAt,
  ];
}
