import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/matters/supabase_matter_api.dart';
import 'package:legalhub/data/matters/supabase_matter_gateway.dart';
import 'package:legalhub/features/matters/domain/matter.dart';

/// Hand-rolled fake of the [SupabaseMatterApi] seam: records calls and
/// answers with canned rows or a [SupabaseMatterException], so the gateway's
/// domain mapping is tested without a provider.
class _StubSupabaseMatterApi implements SupabaseMatterApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseMatterException? error;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchMatters() async {
    calls += 1;
    if (error != null) {
      throw error!;
    }
    return rows;
  }
}

/// Hand-rolled fake of the [OrganizationGateway] roster seam for name
/// resolution: answers `listMembers` with a canned outcome and records the
/// requested organization ids.
class _StubOrganizationGateway implements OrganizationGateway {
  OrgOutcome<List<OrgMember>>? listMembersResult;
  final List<String> rosterCalls = <String>[];

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) async {
    rosterCalls.add(organizationId);
    return listMembersResult ??
        const OrgOutcome<List<OrgMember>>.failure(
          OrgFailure(kind: OrgFailureKind.denied),
        );
  }

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) => throw UnimplementedError();

  @override
  Future<OrgOutcome<String>> resendInvitation({required String invitationId}) =>
      throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> revokeInvitation({required String invitationId}) =>
      throw UnimplementedError();

  @override
  Future<OrgOutcome<void>> deleteMyAccount() => throw UnimplementedError();

  @override
  Future<OrgOutcome<String>> acceptInvitation({required String token}) =>
      throw UnimplementedError();
}

OrgMember _member(
  String userId,
  String displayName, {
  UserRole role = UserRole.attorney,
}) {
  final DateTime time = DateTime.utc(2026, 7, 25);
  return OrgMember(
    organizationId: 'org-1',
    userId: userId,
    displayName: displayName,
    locale: 'en',
    role: role,
    status: MembershipStatus.active,
    createdAt: time,
    updatedAt: time,
  );
}

Map<String, dynamic> _row({
  String id = 'm-1',
  String organizationId = 'org-1',
  String title = 'Demo acquisition review',
  String practiceArea = 'corporate',
  String status = 'active',
  String? attorneyId = 'attorney-1',
  String createdAt = '2026-08-07T10:00:00.000Z',
}) => <String, dynamic>{
  'id': id,
  'organization_id': organizationId,
  'title': title,
  'practice_area': practiceArea,
  'status': status,
  'assigned_attorney_id': attorneyId,
  'created_at': createdAt,
};

void main() {
  late _StubSupabaseMatterApi api;
  late _StubOrganizationGateway orgGateway;
  late SupabaseMatterGateway gateway;

  setUp(() {
    api = _StubSupabaseMatterApi();
    orgGateway = _StubOrganizationGateway();
    gateway = SupabaseMatterGateway(api, orgGateway);
  });

  group('row → Matter mapping (D-MR7)', () {
    test(
      'maps a full row to the Matter VO with the roster display name',
      () async {
        api.rows = <Map<String, dynamic>>[_row()];
        orgGateway.listMembersResult = OrgOutcome<List<OrgMember>>.success(
          <OrgMember>[_member('attorney-1', 'Layla Mansour')],
        );

        final Result<List<Matter>> result = await gateway.fetchMatters();

        expect(result.isSuccess, isTrue);
        final Matter matter = result.valueOrNull!.single;
        expect(matter.id, 'm-1');
        expect(matter.title, 'Demo acquisition review');
        expect(matter.practiceArea, PracticeArea.corporate);
        expect(matter.status, MatterStatus.active);
        expect(matter.assignedAttorneyName, 'Layla Mansour');
        expect(
          matter.createdAt,
          DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
        );
      },
    );

    test('maps every practice area and status name', () async {
      api.rows = <Map<String, dynamic>>[
        _row(id: 'm-1', practiceArea: 'corporate', status: 'open'),
        _row(id: 'm-2', practiceArea: 'civil', status: 'active'),
        _row(id: 'm-3', practiceArea: 'criminal', status: 'closed'),
        _row(id: 'm-4', practiceArea: 'family', status: 'open'),
      ];

      final List<Matter> matters = (await gateway.fetchMatters()).valueOrNull!;

      expect(matters.map((Matter m) => m.practiceArea), <PracticeArea>[
        PracticeArea.corporate,
        PracticeArea.civil,
        PracticeArea.criminal,
        PracticeArea.family,
      ]);
      expect(matters.map((Matter m) => m.status), <MatterStatus>[
        MatterStatus.open,
        MatterStatus.active,
        MatterStatus.closed,
        MatterStatus.open,
      ]);
    });

    test('parses created_at and converts to local time', () async {
      api.rows = <Map<String, dynamic>>[_row()];

      final Matter matter = (await gateway.fetchMatters()).valueOrNull!.single;

      expect(
        matter.createdAt,
        DateTime.parse('2026-08-07T10:00:00.000Z').toLocal(),
      );
    });

    test('resolves the attorney name from the org roster (D-MR4)', () async {
      api.rows = <Map<String, dynamic>>[_row(attorneyId: 'attorney-9')];
      orgGateway.listMembersResult =
          OrgOutcome<List<OrgMember>>.success(<OrgMember>[
            _member('attorney-9', 'Sara Khalil'),
            _member('someone-else', 'Other Attorney'),
          ]);

      final Matter matter = (await gateway.fetchMatters()).valueOrNull!.single;

      expect(matter.assignedAttorneyName, 'Sara Khalil');
      expect(orgGateway.rosterCalls, <String>['org-1']);
    });

    test('asks the roster once per distinct organization', () async {
      api.rows = <Map<String, dynamic>>[
        _row(id: 'm-1', organizationId: 'org-1', attorneyId: 'a-1'),
        _row(id: 'm-2', organizationId: 'org-2', attorneyId: 'a-2'),
        _row(id: 'm-3', organizationId: 'org-1', attorneyId: 'a-1'),
      ];

      final List<Matter> matters = (await gateway.fetchMatters()).valueOrNull!;

      expect(orgGateway.rosterCalls.toSet(), <String>{'org-1', 'org-2'});
      expect(orgGateway.rosterCalls, hasLength(2));
      expect(matters, hasLength(3));
    });

    test('falls back to the raw id when the id is not on the roster', () async {
      api.rows = <Map<String, dynamic>>[_row(attorneyId: 'unknown-id')];
      orgGateway.listMembersResult = OrgOutcome<List<OrgMember>>.success(
        <OrgMember>[_member('attorney-1', 'Layla Mansour')],
      );

      final Matter matter = (await gateway.fetchMatters()).valueOrNull!.single;

      expect(matter.assignedAttorneyName, 'unknown-id');
    });

    test(
      'falls back to the raw id when the roster is unavailable (plan §9)',
      () async {
        api.rows = <Map<String, dynamic>>[_row(attorneyId: 'attorney-1')];
        orgGateway.listMembersResult =
            const OrgOutcome<List<OrgMember>>.failure(
              OrgFailure(kind: OrgFailureKind.denied),
            );

        final Result<List<Matter>> result = await gateway.fetchMatters();

        // Roster denied: names fall back, the fetch still succeeds.
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.single.assignedAttorneyName, 'attorney-1');
      },
    );

    test('projects the unassigned constant for a null attorney', () async {
      api.rows = <Map<String, dynamic>>[_row(attorneyId: null)];

      final Matter matter = (await gateway.fetchMatters()).valueOrNull!.single;

      expect(
        matter.assignedAttorneyName,
        SupabaseMatterGateway.unassignedAttorneyName,
      );
    });

    test('returns an empty success for no rows', () async {
      final Result<List<Matter>> result = await gateway.fetchMatters();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('loud provider-drift handling', () {
    test('an unknown status name fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(status: 'archived')];

      final Result<List<Matter>> result = await gateway.fetchMatters();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'matter_read_failed');
    });

    test('an unknown practice area fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[_row(practiceArea: 'tax')];

      final Result<List<Matter>> result = await gateway.fetchMatters();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'matter_read_failed');
    });

    test('a missing title fails the fetch loudly', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'm-1', 'organization_id': 'org-1'},
      ];

      final Result<List<Matter>> result = await gateway.fetchMatters();

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull?.code, 'matter_read_failed');
    });
  });

  group('failure mapping (contract §5)', () {
    test('maps a denied read to the denied AppError code', () async {
      api.error = const SupabaseMatterException(
        kind: SupabaseMatterFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<Matter>> result = await gateway.fetchMatters();

      final AppError error = result.errorOrNull!;
      expect(error.code, 'matter_read_denied');
      expect(error.technicalMessage, 'permission denied');
    });

    test(
      'maps an unknown failure to the generic code with no row content',
      () async {
        api.error = const SupabaseMatterException(
          kind: SupabaseMatterFailureKind.unknown,
          message: 'provider hiccup',
        );
        api.rows = <Map<String, dynamic>>[_row(title: 'Sensitive case title')];

        final Result<List<Matter>> result = await gateway.fetchMatters();

        final AppError error = result.errorOrNull!;
        expect(error.code, 'matter_read_failed');
        // The error never carries row content (redaction-safe context).
        expect(error.technicalMessage, 'provider hiccup');
        expect(error.toString(), isNot(contains('Sensitive')));
        expect(error.context, isEmpty);
      },
    );
  });
}
