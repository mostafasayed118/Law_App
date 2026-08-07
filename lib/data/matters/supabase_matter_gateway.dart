import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../core/organizations/organization_gateway.dart';
import '../../core/practice_area.dart';
import '../../features/matters/domain/matter.dart';
import '../../features/matters/domain/matter_gateway.dart';
import 'supabase_matter_api.dart';

/// [MatterGateway] backed by the Supabase provider via [SupabaseMatterApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseOrganizationGateway]): raw rows from the seam become [Matter]
/// VOs, status/practice-area strings map to the client enums with a loud
/// failure on unknown values (provider drift, never a silently wrong enum),
/// and typed [SupabaseMatterException]s become [AppError]s. The `Matter` VO
/// and all presentation are untouched — this is the env-gated seam-compatible
/// swap of plan T7 (D-MR7).
///
/// **Display-name resolution (D-MR4):** rows carry ids only; the roster RPC
/// (`OrganizationGateway.listMembers` → `list_org_members_metadata`) is the
/// shipped name-resolution seam (the `profiles` join is blocked by own-row
/// RLS, D-T6). The assigned attorney's display name comes from the matter's
/// org roster, falling back to the raw id when the roster is unavailable or
/// the id is not a member (plan §9) — never a fabricated name, never a
/// cross-seam profile leak.
class SupabaseMatterGateway implements MatterGateway {
  SupabaseMatterGateway(this._api, this._orgGateway);

  final SupabaseMatterApi _api;
  final OrganizationGateway _orgGateway;

  /// Display-name fallback for a matter with no assigned attorney. The row
  /// legitimately carries a NULL `assigned_attorney_id` (a client-assigned
  /// matter before an attorney joins); the VO requires a non-empty display
  /// string, so a generic neutral value is projected — honest, never a
  /// fabricated identity.
  static const String unassignedAttorneyName = 'Unassigned';

  @override
  Future<Result<List<Matter>>> fetchMatters() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchMatters();
      final Map<String, String> displayNames = await _displayNamesFor(
        rows.map(_organizationIdOf),
      );
      return Result<List<Matter>>.success(
        List<Matter>.unmodifiable(
          rows.map(
            (Map<String, dynamic> row) => _matterFromRow(row, displayNames),
          ),
        ),
      );
    } on SupabaseMatterException catch (e) {
      return Result<List<Matter>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected status/practice-area/date shape) surfaces
      // loudly, never as a silently wrong matter.
      return Result<List<Matter>>.failure(
        AppError(
          code: 'matter_read_failed',
          userMessage: 'Unable to load matters. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Builds a userId → displayName map from the roster seam for every
  /// distinct organization the fetched rows reference.
  ///
  /// A roster failure for one org never fails the whole fetch: names for
  /// that org fall back to the raw id (plan §9) while every other org's
  /// names still resolve. The roster RPC's in-body guard already limits it
  /// to active members, so this never leaks beyond the shipped seam.
  Future<Map<String, String>> _displayNamesFor(
    Iterable<String> organizationIds,
  ) async {
    final Map<String, String> names = <String, String>{};
    for (final String organizationId in organizationIds.toSet()) {
      final OrgOutcome<List<OrgMember>> outcome = await _orgGateway.listMembers(
        organizationId: organizationId,
      );
      if (outcome is OrgFailed<List<OrgMember>>) {
        // Roster unavailable for this org: id fallback, keep the rest.
        continue;
      }
      for (final OrgMember member
          in outcome.valueOrNull ?? const <OrgMember>[]) {
        names[member.userId] = member.displayName;
      }
    }
    return names;
  }

  String _organizationIdOf(Map<String, dynamic> row) =>
      row['organization_id'] as String;

  /// Maps one raw matter row to the [Matter] VO.
  ///
  /// [displayNames] is the roster-derived userId → displayName map; the
  /// assigned attorney's name resolves through it with the id (or the
  /// unassigned constant) as the honest fallback.
  Matter _matterFromRow(
    Map<String, dynamic> row,
    Map<String, String> displayNames,
  ) {
    final String id = row['id'] as String;
    final Object? title = row['title'];
    if (title is! String || title.isEmpty) {
      throw FormatException('Matter row has no title');
    }
    final String? attorneyId = row['assigned_attorney_id'] as String?;
    final String attorneyName = attorneyId == null
        ? unassignedAttorneyName
        : displayNames[attorneyId] ?? attorneyId;
    return Matter(
      id: id,
      title: title,
      practiceArea: _practiceAreaFromServerName(
        row['practice_area'] as String?,
      ),
      status: _statusFromServerName(row['status'] as String?),
      assignedAttorneyName: attorneyName,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  /// Maps a server `practice_area` name to the domain [PracticeArea], or
  /// throws when the name is unknown (provider drift — surfaces loudly,
  /// never silently as an area the client does not understand).
  PracticeArea _practiceAreaFromServerName(String? name) {
    return switch (name) {
      'corporate' => PracticeArea.corporate,
      'civil' => PracticeArea.civil,
      'criminal' => PracticeArea.criminal,
      'family' => PracticeArea.family,
      _ => throw FormatException('Unknown matter practice area: $name'),
    };
  }

  /// Maps a server `status` name to the domain [MatterStatus], or throws on
  /// an unknown name (same loud-drift discipline as the area mapping).
  MatterStatus _statusFromServerName(String? name) {
    return switch (name) {
      'open' => MatterStatus.open,
      'active' => MatterStatus.active,
      'closed' => MatterStatus.closed,
      _ => throw FormatException('Unknown matter status: $name'),
    };
  }

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — matter row
  /// content never crosses into errors.
  AppError _mapFailure(SupabaseMatterException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseMatterFailureKind.denied => (
        'matter_read_denied',
        'You do not have permission to view these matters.',
      ),
      SupabaseMatterFailureKind.providerUnavailable => (
        'matter_read_unavailable',
        'Matters are temporarily unavailable. Please try again.',
      ),
      SupabaseMatterFailureKind.unknown => (
        'matter_read_failed',
        'Unable to load matters. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }
}
