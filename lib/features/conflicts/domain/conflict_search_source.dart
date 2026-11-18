import 'package:legalhub/features/matters/domain/matter.dart';

/// Read-only source for the local, deterministic conflict check.
///
/// Implemented in `data/` by delegating to the EXISTING matter gateway — no new
/// backend, RPC, table, or fuzzy matcher. No invented data crosses this seam.
abstract interface class ConflictSearchSource {
  /// Matters returned by the matter gateway's own substring search for
  /// [partyName], already refined to attorney-name/title matches.
  Future<List<Matter>> matchesForParty(String partyName);

  /// Total matters available for the "Checked N parties against M matters"
  /// sentence. A real count from `fetchMatters()`, never a fabricated number.
  Future<int> availableMatterCount();
}
