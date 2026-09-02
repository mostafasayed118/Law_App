import '../../../core/errors/result.dart';
import '../../documents/domain/document.dart';
import '../../documents/domain/document_gateway.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../domain/ai_finding.dart';
import '../domain/ai_gateway.dart';

/// Demo-posture synthetic research engine (AI research slice, plan 1.0).
///
/// The **fake-gateway pattern** behind the `AiGateway` seam (ratified scope
/// decision D-1 — no model provider). `research` reads the **shipped
/// gateway seams only** (D-2): it fetches the synthetic document rows via
/// [documentGateway] and the synthetic matter rows via [matterGateway],
/// matches the query tokens case-insensitively against their title/type and
/// title/practice-area fields, and composes deterministic findings with
/// citation rows (B-3/C-2 — every finding cites its matched rows).
///
/// Honesty rails:
/// - **no fabricated matches** — a query that matches nothing yields an
///   empty list (AC-2), never invented findings;
/// - **deterministic** — the same corpus + query produce byte-identical
///   findings (AC-1);
/// - **no persistence** — nothing about the query or the findings is
///   retained after the call (C-1);
/// - **upstream failures pass through typed** — a document/matter gateway
///   failure maps to the seam's typed failure (AC-3), never raw exceptions;
/// - **synthetic copy only** — every headline/summary/excerpt is static
///   demo wording that must never read as real legal analysis or advice
///   (A-3/C-3).
class SyntheticAiGateway implements AiGateway {
  /// Creates the engine over the two shipped read seams (D-2). Both are
  /// required: the demo corpus is exactly their union.
  const SyntheticAiGateway({
    required this.documentGateway,
    required this.matterGateway,
  });

  /// The shipped document read seam — half of the demo corpus (D-2).
  final DocumentGateway documentGateway;

  /// The shipped matter read seam — the other half of the corpus (D-2).
  final MatterGateway matterGateway;

  @override
  Future<Result<List<AiFinding>>> research(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // An empty query has no findings — same honest-empty posture as the
      // unified-search slice (no fetches, no fabricated rows).
      return Result<List<AiFinding>>.success(const <AiFinding>[]);
    }

    final documents = await documentGateway.fetchDocuments();
    if (documents is Failure<List<Document>>) {
      return Result<List<AiFinding>>.failure(documents.error);
    }
    final matters = await matterGateway.fetchMatters();
    if (matters is Failure<List<Matter>>) {
      return Result<List<AiFinding>>.failure(matters.error);
    }

    final tokens = _tokenize(trimmed);
    if (tokens.isEmpty) {
      return Result<List<AiFinding>>.success(const <AiFinding>[]);
    }

    final findings = <AiFinding>[];
    for (final document in documents.valueOrNull ?? const <Document>[]) {
      if (_matches(_documentHaystack(document), tokens)) {
        findings.add(_findingForDocument(document));
      }
    }
    for (final matter in matters.valueOrNull ?? const <Matter>[]) {
      if (_matches(_matterHaystack(matter), tokens)) {
        findings.add(_findingForMatter(matter));
      }
    }
    return Result<List<AiFinding>>.success(
      List<AiFinding>.unmodifiable(findings),
    );
  }

  static List<String> _tokenize(String query) => query
      .toLowerCase()
      .split(RegExp(r'[\s,.;:!?()\-_/]+'))
      .where((token) => token.length >= 3)
      .toList(growable: false);

  static String _documentHaystack(Document document) =>
      '${document.title} ${document.matterRef} ${document.type.name}'
          .toLowerCase();

  static String _matterHaystack(Matter matter) =>
      '${matter.title} ${matter.practiceArea.name} ${matter.status.name}'
          .toLowerCase();

  static bool _matches(String haystack, List<String> tokens) =>
      tokens.any(haystack.contains);

  static AiFinding _findingForDocument(Document document) => AiFinding(
    id: 'research-${document.id}',
    headline: 'Research note — ${document.title}',
    summary:
        'Demo research note compiled from the synthetic corpus row '
        '"${document.title}" (${document.matterRef}). This is static '
        'demo copy generated for the demo corpus — not legal analysis.',
    excerpt:
        'Corpus excerpt: ${document.type.name} metadata row, '
        'matter ref "${document.matterRef}".',
    sources: <AiSource>[
      AiSource(
        kind: AiSourceKind.document,
        title: document.title,
        detail: document.type.name,
      ),
      AiSource(
        kind: AiSourceKind.matter,
        title: document.matterRef,
        detail: 'related demo matter',
      ),
    ],
  );

  static AiFinding _findingForMatter(Matter matter) => AiFinding(
    id: 'research-${matter.id}',
    headline: 'Research note — ${matter.title}',
    summary:
        'Demo research note compiled from the synthetic corpus row '
        '"${matter.title}" (${matter.practiceArea.name}). This is '
        'static demo copy generated for the demo corpus — not legal '
        'analysis.',
    excerpt:
        'Corpus excerpt: ${matter.status.name} matter row, '
        'practice area "${matter.practiceArea.name}".',
    sources: <AiSource>[
      AiSource(
        kind: AiSourceKind.matter,
        title: matter.title,
        detail: matter.practiceArea.name,
      ),
    ],
  );
}
