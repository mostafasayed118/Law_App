import 'package:equatable/equatable.dart';

/// The kind of shipped seam a research finding cites (slice 1.0, D-2).
///
/// The AI corpus is the **shipped gateway seams only** (ratified scope
/// decision D-2 — `docs/ai_scope_decision_2026-08-11.md`): every source a
/// finding cites is either a document row from `DocumentGateway` or a
/// matter row from `MatterGateway`. No AI-only corpus exists, so no other
/// kind exists (the enum-pin test enforces the set).
enum AiSourceKind { document, matter }

/// A citation row attached to an [AiFinding] (slice 1.0, B-3/C-2).
///
/// Synthetic non-PII metadata only: the cited seam's kind, the generic demo
/// title of the cited row, and one demo detail line (document type name or
/// practice-area name — static synthetic copy). **Every finding carries at
/// least one source, and the row renders unconditionally** (C-2 — sources
/// are never toggleable); the structural pin lives in the gateway tests.
class AiSource extends Equatable {
  const AiSource({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final AiSourceKind kind;

  /// Generic demo wording — never a real client, case, or file reference.
  final String title;

  /// Static synthetic copy (document type / practice area), never advice.
  final String detail;

  @override
  List<Object?> get props => <Object?>[kind, title, detail];
}

/// A synthetic research finding (slice 1.0, A-2/B-3).
///
/// The demo-posture answer to the research-assistant surface: a headline +
/// summary + excerpt, all **static synthetic copy** that must never read as
/// real legal analysis or advice (A-3/C-3), plus the citation rows pointing
/// at the shipped demo rows it was matched from (B-3). The type carries no
/// score, no confidence, no clearance semantics — the no-false-assurance
/// rule (INSTRUCTIONS §1.3 #5) is structural here.
class AiFinding extends Equatable {
  const AiFinding({
    required this.id,
    required this.headline,
    required this.summary,
    required this.excerpt,
    required this.sources,
  });

  /// Stable synthetic id — deterministic for a given corpus row match.
  final String id;

  /// Short generic demo headline derived from the matched row's title.
  final String headline;

  /// One-paragraph synthetic summary; static demo copy, never advice.
  final String summary;

  /// A synthetic excerpt line pointing at the matched row's metadata.
  final String excerpt;

  /// The citation rows — always non-empty (C-2), rendered unconditionally.
  final List<AiSource> sources;

  @override
  List<Object?> get props => <Object?>[id, headline, summary, excerpt, sources];
}
