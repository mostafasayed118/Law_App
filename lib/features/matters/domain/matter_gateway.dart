import '../../../core/errors/result.dart';
import 'matter.dart';

/// Matter dashboard integration boundary (Phase 7, slice 7.1).
///
/// Mirrors the credential-free discipline of [AttorneyGateway]/[BookingGateway]
/// (Phase 6 D-A2 / Phase 5 D-B3): this slice deliberately has no real
/// backend. A fake/in-memory implementation is registered for dev so the
/// matter surface can exercise the read-first lifecycle; no real matter data
/// crosses this boundary yet, and the real data path (table, RLS, storage,
/// realtime) stays deferred per roadmap §11 until P0 closes + policy tests
/// exist (owner decision D-M2/D-M3).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class MatterGateway {
  /// The synthetic matter list for the dashboard. Deterministic and
  /// read-first (owner decisions D-M1/D-M2/D-M4).
  Future<Result<List<Matter>>> fetchMatters();
}
