import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/organizations/membership_repository.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/supabase_membership_repository.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';

/// Hand-rolled fake of the [SupabaseOrgApi] membership SELECT surface:
/// answers [listMyMemberships] with canned rows or a [SupabaseOrgException].
class _StubOrgApi implements SupabaseOrgApi {
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  SupabaseOrgException? error;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships() async {
    calls += 1;
    if (error != null) {
      throw error!;
    }
    return rows;
  }

  @override
  Future<String> createOrganization({required String name}) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async => throw UnimplementedError();

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async => throw UnimplementedError();

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async => throw UnimplementedError();

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async => throw UnimplementedError();

  @override
  Future<String> resendInvitation({required String invitationId}) async =>
      throw UnimplementedError();

  @override
  Future<void> revokeInvitation({required String invitationId}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteMyAccount() async => throw UnimplementedError();

  @override
  Future<String> acceptInvitation({required String token}) async =>
      throw UnimplementedError();
}

void main() {
  late _StubOrgApi api;
  late SupabaseMembershipRepository repository;

  setUp(() {
    api = _StubOrgApi();
    repository = SupabaseMembershipRepository(api);
  });

  Map<String, dynamic> activeRow({
    String organizationId = 'org-1',
    String? organizationName = 'Demo Firm',
    String role = 'partner',
    String status = 'active',
  }) => <String, dynamic>{
    'organization_id': organizationId,
    'role': role,
    'status': status,
    if (organizationName != null)
      'organizations': <String, dynamic>{'name': organizationName},
  };

  /// Unwraps a succeeded hydration for the row-mapping assertions.
  Future<List<OrganizationMembership>> loadSucceeded() async {
    final MembershipHydrationResult result = await repository.loadMemberships(
      userId: 'u-1',
    );
    expect(result, isA<HydrationSucceeded>());
    return (result as HydrationSucceeded).memberships;
  }

  group('SupabaseMembershipRepository.loadMemberships', () {
    test('maps active rows with the embedded org name', () async {
      api.rows = <Map<String, dynamic>>[
        activeRow(organizationId: 'org-1', organizationName: 'Demo Firm'),
      ];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      expect(memberships, hasLength(1));
      final OrganizationMembership membership = memberships.single;
      expect(membership.organizationId, 'org-1');
      expect(membership.organizationName, 'Demo Firm');
      expect(membership.role, UserRole.partner);
      expect(membership.status, MembershipStatus.active);
      expect(membership.isActive, isTrue);
      expect(api.calls, 1);
    });

    test('tolerates a null org name for a suspended/removed membership '
        '(plan §6 name-resolution note)', () async {
      api.rows = <Map<String, dynamic>>[
        activeRow(
          organizationId: 'org-1',
          organizationName: null,
          status: 'suspended',
        ),
      ];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      expect(memberships, hasLength(1));
      final OrganizationMembership membership = memberships.single;
      expect(membership.organizationId, 'org-1');
      expect(membership.organizationName, isNull);
      expect(membership.status, MembershipStatus.suspended);
      expect(membership.isActive, isFalse);
    });

    test('drops an unknown schema role loudly (D-P32.1)', () async {
      api.rows = <Map<String, dynamic>>[
        activeRow(role: 'researchAnalyst'),
        activeRow(organizationId: 'org-2', organizationName: 'Second Firm'),
      ];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      // Only the well-understood row survives; the unknown-role row must not
      // project any capability hint.
      expect(memberships, hasLength(1));
      expect(memberships.single.organizationId, 'org-2');
    });

    test('drops an unknown status row loudly (D-P32.1)', () async {
      api.rows = <Map<String, dynamic>>[
        activeRow(status: 'expired'),
        activeRow(organizationId: 'org-2', organizationName: 'Second Firm'),
      ];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      expect(memberships, hasLength(1));
      expect(memberships.single.organizationId, 'org-2');
    });

    test('drops a row without an organization id', () async {
      api.rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'partner',
          'status': 'active',
          'organizations': <String, dynamic>{'name': 'X'},
        },
      ];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      expect(memberships, isEmpty);
    });

    test('provider read failure is a typed HydrationFailed (Task 8)', () async {
      api.error = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.providerUnavailable,
        message: 'offline',
      );

      final MembershipHydrationResult result = await repository.loadMemberships(
        userId: 'u-1',
      );

      // The typed outcome lets the cubit seam distinguish failure from the
      // honest empty — never a fabricated membership, never a session
      // invalidation.
      expect(result, isA<HydrationFailed>());
      expect(
        (result as HydrationFailed).kind,
        MembershipHydrationFailureKind.providerUnavailable,
      );
    });

    test('a denied read maps to the denied failure kind', () async {
      api.error = const SupabaseOrgException(
        kind: SupabaseOrgFailureKind.denied,
        message: 'forbidden',
      );

      final MembershipHydrationResult result = await repository.loadMemberships(
        userId: 'u-1',
      );

      expect(result, isA<HydrationFailed>());
      expect(
        (result as HydrationFailed).kind,
        MembershipHydrationFailureKind.denied,
      );
    });

    test('provider reports no memberships → honest empty succeeded', () async {
      api.rows = const <Map<String, dynamic>>[];

      final List<OrganizationMembership> memberships = await loadSucceeded();

      expect(memberships, isEmpty);
    });
  });
}
