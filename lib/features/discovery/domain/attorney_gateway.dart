import '../../../core/errors/result.dart';
import 'attorney.dart';

/// Attorney-discovery integration boundary (Phase 6, slice 6.1).
///
/// Mirrors the credential-free discipline of [SignUpGateway]/[BookingGateway]:
/// this slice deliberately has no real backend. A fake/in-memory implementation
/// is registered for dev so the search surface can exercise the discovery
/// lifecycle; no real attorney data crosses this boundary yet, and the real
/// data contract is deferred to P2/P3 (owner decision D-A2).
///
/// Return convention matches the project's [Result] boundary (§D.4) — failures
/// arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class AttorneyGateway {
  /// The synthetic attorney list for the search surface. Deterministic and
  /// availability-free (owner decisions D-A2/D-A4).
  Future<Result<List<Attorney>>> fetchAttorneys();
}
