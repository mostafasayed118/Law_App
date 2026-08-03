import '../../../core/errors/result.dart';
import '../domain/document.dart';
import '../domain/document_gateway.dart';

/// Development-only document implementation: a fixed synthetic list of
/// non-PII document **metadata**.
///
/// No real backend, no storage, no document bodies, no e-signature (owner
/// decisions D-V1/D-V2/D-V4): [fetchDocuments] returns the same
/// deterministic list on every call. Documents carry id / generic demo
/// title / document type / created date only — **no body, no content, no
/// size, no download URL, no client or real-looking file references
/// (D-V4)**, and titles are static demo copy that must never read as a real
/// file (R1). The list resolves immediately (no artificial delay) so
/// cubit/widget tests stay timing-independent.
class FakeDocumentGateway implements DocumentGateway {
  /// The fixed synthetic document-metadata list served by [fetchDocuments].
  static final List<Document> syntheticDocuments = <Document>[
    Document(
      id: 'doc-1',
      title: 'Demo engagement letter',
      type: DocumentType.contract,
      createdAt: DateTime.utc(2026, 7, 10),
    ),
    Document(
      id: 'doc-2',
      title: 'Sample matter brief — demo',
      type: DocumentType.brief,
      createdAt: DateTime.utc(2026, 7, 15),
    ),
    Document(
      id: 'doc-3',
      title: 'Demo evidence index',
      type: DocumentType.evidence,
      createdAt: DateTime.utc(2026, 7, 19),
    ),
    Document(
      id: 'doc-4',
      title: 'Correspondence log — demo',
      type: DocumentType.correspondence,
      createdAt: DateTime.utc(2026, 7, 22),
    ),
    Document(
      id: 'doc-5',
      title: 'Demo settlement draft',
      type: DocumentType.contract,
      createdAt: DateTime.utc(2026, 7, 26),
    ),
  ];

  @override
  Future<Result<List<Document>>> fetchDocuments() async {
    // Metadata only — the synthetic list is returned as-is; nothing crosses
    // this boundary but the D-V4 metadata surface.
    return Result<List<Document>>.success(syntheticDocuments);
  }
}
