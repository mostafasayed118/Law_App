import 'package:equatable/equatable.dart';

import 'package:legalhub/core/validation/uuid.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';

/// One document in the Legal Library — a statute, a regulation or a ruling.
///
/// Metadata only. The article bodies live in separate rows and are read through
/// [LegalDocumentDetail]; a list screen must never pull every body just to show
/// a title.
///
/// [isSample] is a truthfulness contract, not a flag of convenience: when it is
/// true the text is invented demonstration content, and presentation is
/// required to render a visible sample badge. Real text imported by the owner
/// carries false.
///
/// [id] stays a [String] because env-less builds serve synthetic `legal-doc-*`
/// rows; [hasRealId] distinguishes those from persisted uuid rows.
class LegalDocument extends Equatable {
  const LegalDocument({
    required this.id,
    required this.sourceId,
    required this.sourceNameAr,
    required this.sourceKind,
    required this.titleAr,
    required this.category,
    required this.status,
    required this.isSample,
    this.titleEn,
    this.officialNumber,
    this.year,
    this.summaryAr,
    this.publishedAt,
    this.articleCount = 0,
  });

  final String id;
  final String sourceId;
  final String sourceNameAr;
  final LegalSourceKind sourceKind;

  /// The Arabic title. Always present: the library is Arabic-first.
  final String titleAr;

  /// The English title when the source published one.
  final String? titleEn;

  /// The official instrument number (e.g. a gazette reference), free text.
  final String? officialNumber;

  final int? year;
  final LegalCategory category;
  final LegalStatus status;
  final String? summaryAr;
  final DateTime? publishedAt;

  /// True when this row is invented demonstration content.
  final bool isSample;

  /// How many articles the document carries, as reported by the list read.
  final int articleCount;

  /// True only when [id] is a real uuid — never for a synthetic `legal-doc-*`.
  bool get hasRealId => isValidUuid(id);

  @override
  List<Object?> get props => <Object?>[
    id,
    sourceId,
    sourceNameAr,
    sourceKind,
    titleAr,
    titleEn,
    officialNumber,
    year,
    category,
    status,
    summaryAr,
    publishedAt,
    isSample,
    articleCount,
  ];
}
