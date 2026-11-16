import 'package:equatable/equatable.dart';

import 'package:legalhub/core/validation/uuid.dart';

/// One article of a [LegalDocument] (ADR-0009).
///
/// [articleNumber] is TEXT, not an integer: real citations include "5 مكرر"
/// ("5 bis") and similar forms, and coercing them to a number would either
/// fail or silently renumber the law. [ordinal] carries the position inside the
/// document for ordering and prev/next navigation.
///
/// [isSample] marks invented demonstration text; the reader renders a visible
/// sample badge whenever it, or its parent document, is sample.
class LegalArticle extends Equatable {
  const LegalArticle({
    required this.id,
    required this.documentId,
    required this.articleNumber,
    required this.ordinal,
    required this.bodyAr,
    required this.isSample,
    this.headingAr,
    this.bodyEn,
  });

  final String id;
  final String documentId;

  /// The citation label as published, e.g. "12" or "5 مكرر".
  final String articleNumber;

  /// 1-based position inside the document.
  final int ordinal;

  final String? headingAr;
  final String bodyAr;
  final String? bodyEn;
  final bool isSample;

  bool get hasRealId => isValidUuid(id);

  @override
  List<Object?> get props => <Object?>[
    id,
    documentId,
    articleNumber,
    ordinal,
    headingAr,
    bodyAr,
    bodyEn,
    isSample,
  ];
}
