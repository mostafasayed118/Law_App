import 'package:equatable/equatable.dart';

/// The kind of seam a research finding cites (slice 1.0, D-2; design §5).
///
/// The synthetic demo corpus is the **shipped gateway seams only** (ratified
/// scope decision D-2 — `docs/ai_scope_decision_2026-08-11.md`): every source
/// it cites is a document or matter row. The real provider's contract also
/// allows `none` — a finding that cites neither — which is surfaced honestly
/// as "no source cited" instead of inventing one.
enum AiSourceKind { document, matter, none }

/// A citation row attached to an [AiFinding] (slice 1.0, B-3/C-2).
///
/// Synthetic findings carry the cited seam's kind plus demo title/detail
/// strings. Real findings carry the server's `source_id` and leave
/// [title]/[detail] empty — presentation renders the localized kind label
/// and the id instead of pretending to know a display title.
class AiSource extends Equatable {
  const AiSource({
    required this.kind,
    required this.title,
    required this.detail,
    this.sourceId,
  });

  final AiSourceKind kind;

  /// Generic demo wording — never a real client, case, or file reference.
  /// Empty for a real server finding, which knows only [sourceId].
  final String title;

  /// Static synthetic copy (document type / practice area), never advice.
  final String detail;

  /// The server's `source_id` for a real finding; null for synthetic rows
  /// and for the `none` kind.
  final String? sourceId;

  @override
  List<Object?> get props => <Object?>[kind, title, detail, sourceId];
}

/// A research finding (slice 1.0, A-2/B-3; design §5).
///
/// Headline + summary + excerpt, plus the citation rows. Synthetic copy is
/// static demo wording that never reads as real legal analysis (A-3/C-3);
/// real copy comes from the model and is labelled AI-generated in the UI.
/// The type carries no score, no confidence, no clearance semantics — the
/// no-false-assurance rule (INSTRUCTIONS §1.3 #5) is structural here.
class AiFinding extends Equatable {
  const AiFinding({
    required this.id,
    required this.headline,
    required this.summary,
    required this.excerpt,
    required this.sources,
  });

  /// Stable synthetic id, or the persisted `research_findings.id`.
  final String id;

  final String headline;

  final String summary;

  /// A short quoted excerpt; empty when the provider returned none.
  final String excerpt;

  /// The citation rows. Synthetic findings always carry at least one
  /// (C-2); real findings may carry a single `none` row.
  final List<AiSource> sources;

  @override
  List<Object?> get props => <Object?>[id, headline, summary, excerpt, sources];
}
