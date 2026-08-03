import '../../../core/errors/result.dart';
import 'document.dart';

/// Document vault integration boundary (Phase 8, slice 8.0).
///
/// Mirrors the credential-free discipline of [MatterGateway] (Phase 7
/// D-M2): this slice deliberately has no real backend. A fake/in-memory
/// implementation is registered for dev so the vault surface can exercise
/// the read-first lifecycle; no real document data crosses this boundary
/// yet, and the real data path (table, RLS, storage, realtime) stays
/// deferred per roadmap §12 until P0 closes + policy tests exist (owner
/// decision D-V2/D-V3).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class DocumentGateway {
  /// The synthetic document-metadata list for the vault. Deterministic and
  /// read-first (owner decisions D-V1/D-V2/D-V4). **Metadata only — no
  /// document body ever crosses this boundary.**
  Future<Result<List<Document>>> fetchDocuments();
}
