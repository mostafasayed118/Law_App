import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/conflicts/domain/conflict_search_source.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';

/// Credential-free adapter over the shipped [MatterGateway]. The Matter model
/// carries no client name, so matching uses the gateway's own case-insensitive
/// substring search on title and the assigned attorney's real display name —
/// never a new fuzzy matcher and never an invented client field.
class MatterGatewayConflictSearchSource implements ConflictSearchSource {
  const MatterGatewayConflictSearchSource(this._gateway);

  final MatterGateway _gateway;

  @override
  Future<List<Matter>> matchesForParty(String partyName) async {
    final String needle = partyName.trim().toLowerCase();
    if (needle.isEmpty) {
      return const <Matter>[];
    }
    final Result<List<Matter>> result = await _gateway.searchMatters(needle);
    if (result case Success<List<Matter>>(value: final List<Matter> matters)) {
      return matters
          .where(
            (Matter matter) =>
                matter.assignedAttorneyName.toLowerCase().contains(needle) ||
                matter.title.toLowerCase().contains(needle),
          )
          .toList(growable: false);
    }
    return const <Matter>[];
  }

  @override
  Future<int> availableMatterCount() async {
    final Result<List<Matter>> result = await _gateway.fetchMatters();
    return switch (result) {
      Success<List<Matter>>(value: final List<Matter> matters) =>
        matters.length,
      Failure<List<Matter>>() => 0,
    };
  }
}
