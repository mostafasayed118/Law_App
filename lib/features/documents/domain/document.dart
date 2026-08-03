import 'package:equatable/equatable.dart';

/// Kind of a synthetic document (Phase 8, D-V4).
///
/// Four values rendered as type chips on the vault surface. The enum-pin
/// test in `document_test.dart` enforces the set (same discipline as the
/// `MatterStatus`/`PracticeArea` pins).
enum DocumentType { contract, brief, evidence, correspondence }

/// A synthetic document-metadata preview (Phase 8, owner decision D-V4).
///
/// Carries **non-PII metadata only**: a stable synthetic id, a generic demo
/// title, a document type, and a created date. **There is no body, no
/// content, no size, no download URL, and no e-signature field anywhere on
/// the type** (D-V1) — the metadata-only line is enforced structurally, so
/// the vault can never render document content. The real documents data
/// path stays §12-deferred and this shape is TBD; documents come only from
/// the fake gateway's fixed synthetic list, and titles are static demo copy
/// (R1: fake-data honesty — nothing here may read as a real file).
class Document extends Equatable {
  const Document({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
  });

  final String id;

  /// Generic demo wording — never a real client, case, or file reference
  /// (D-V4).
  final String title;

  final DocumentType type;

  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[id, title, type, createdAt];
}
