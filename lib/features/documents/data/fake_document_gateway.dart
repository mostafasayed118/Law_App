import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/pagination.dart';
import 'package:legalhub/features/documents/domain/document.dart';
import 'package:legalhub/features/documents/domain/document_gateway.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

/// Development-only document implementation: a fixed synthetic list of
/// non-PII document **metadata**.
///
/// No real backend, no storage, no document bodies, no e-signature (owner
/// decisions D-V1/D-V2/D-V4): [fetchDocuments] returns the same
/// deterministic list on every call. Documents carry id / generic demo
/// title / matter reference (one of the known synthetic matter titles,
/// D-W2) / document type / created date only — **no body, no content, no
/// size, no download URL, no client or real-looking file references
/// (D-V4)**, and titles are static demo copy that must never read as a real
/// file (R1). The list resolves immediately (no artificial delay) so
/// cubit/widget tests stay timing-independent.
class FakeDocumentGateway implements DocumentGateway {
  /// The fixed synthetic document-metadata list served by [fetchDocuments].
  static final List<Document> syntheticDocuments = <Document>[
    Document(
      id: 'doc-1',
      matterId: DemoCorpus.matterIds[0],
      matterTitle: DemoCorpus.matterTitleAcquisition,
      title: 'Demo engagement letter',
      matterRef: DemoCorpus.matterTitleAcquisition,
      type: DocumentType.contract,
      createdAt: DateTime.utc(2026, 7, 10),
    ),
    Document(
      id: 'doc-2',
      matterId: DemoCorpus.matterIds[1],
      matterTitle: DemoCorpus.matterTitleLease,
      title: 'Sample matter brief — demo',
      matterRef: DemoCorpus.matterTitleLease,
      type: DocumentType.brief,
      createdAt: DateTime.utc(2026, 7, 15),
    ),
    Document(
      id: 'doc-3',
      matterId: DemoCorpus.matterIds[2],
      matterTitle: DemoCorpus.matterTitleProcedural,
      title: 'Demo evidence index',
      matterRef: DemoCorpus.matterTitleProcedural,
      type: DocumentType.evidence,
      createdAt: DateTime.utc(2026, 7, 19),
    ),
    Document(
      id: 'doc-4',
      matterId: DemoCorpus.matterIds[3],
      matterTitle: DemoCorpus.matterTitleFamily,
      title: 'Correspondence log — demo',
      matterRef: DemoCorpus.matterTitleFamily,
      type: DocumentType.correspondence,
      createdAt: DateTime.utc(2026, 7, 22),
    ),
    Document(
      id: 'doc-5',
      matterId: DemoCorpus.matterIds[4],
      matterTitle: DemoCorpus.matterTitleStartup,
      title: 'Demo settlement draft',
      matterRef: DemoCorpus.matterTitleStartup,
      type: DocumentType.contract,
      createdAt: DateTime.utc(2026, 7, 26),
    ),
  ];

  @override
  Future<Result<List<Document>>> fetchDocuments({String? matterId}) async {
    // Metadata only — the synthetic list is returned as-is; nothing crosses
    // this boundary but the D-V4 metadata surface. A matter id scopes the
    // in-memory read the same way the server-side filter does.
    if (matterId == null) {
      return Result<List<Document>>.success(syntheticDocuments);
    }
    return Result<List<Document>>.success(
      syntheticDocuments
          .where((Document document) => document.matterId == matterId)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Document>>> searchDocuments(
    String query, {
    int limit = kSearchPageSize,
  }) async {
    // In-memory backend: no transfer cost to save, so no prefilter — the
    // caller's full matching pass is the arbiter and results stay identical
    // to the fetchDocuments path.
    return fetchDocuments();
  }
}
