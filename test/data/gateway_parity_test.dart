import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/data/orgs/supabase_org_api.dart';
import 'package:legalhub/data/orgs/supabase_organization_gateway.dart';

/// R5 — gateway parity (2026-09-24).
///
/// The `fake_*` / `supabase_*` gateway pairs are a deliberate seam, not
/// copy-paste — but nothing pinned that the fakes agree with production on
/// failure vocabulary, so the fakes could pass while production breaks (or
/// vice versa). These contract tests drive the SAME scenarios through BOTH
/// implementations and assert the SAME [OrgFailureKind] comes out, keeping
/// the seam honest.
class _StubOrgApi implements SupabaseOrgApi {
  SupabaseOrgException? error;

  @override
  Future<String> createOrganization({required String name}) async {
    if (error != null) {
      throw error!;
    }
    return 'org-remote';
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers({
    required String organizationId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> listAssignableMembers({
    required String matterId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> listMyMemberships() async {
    if (error != null) {
      throw error!;
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<String> inviteMember({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    if (error != null) {
      throw error!;
    }
    return 'token-remote';
  }

  @override
  Future<void> changeMemberRole({
    required String organizationId,
    required String userId,
    required String role,
  }) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> suspendMember({
    required String organizationId,
    required String userId,
  }) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> reactivateMember({
    required String organizationId,
    required String userId,
  }) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<String> resendInvitation({required String invitationId}) async {
    if (error != null) {
      throw error!;
    }
    return 'token-remote';
  }

  @override
  Future<void> revokeInvitation({required String invitationId}) async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<void> deleteMyAccount() async {
    if (error != null) {
      throw error!;
    }
  }

  @override
  Future<String> acceptInvitation({required String token}) async {
    if (error != null) {
      throw error!;
    }
    return 'membership-remote';
  }

  @override
  Future<List<Map<String, dynamic>>> readOrgAudit({
    required String organizationId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return const <Map<String, dynamic>>[];
  }
}

void main() {
  group('gateway parity: same scenario, same OrgFailureKind', () {
    test('empty org name → invalidName on both', () async {
      final FakeOrganizationGateway fake = FakeOrganizationGateway();
      final _StubOrgApi stub = _StubOrgApi();
      final SupabaseOrganizationGateway remote = SupabaseOrganizationGateway(
        stub,
      );

      expect(
        (await fake.createOrganization(name: '  ')).failureOrNull?.kind,
        OrgFailureKind.invalidName,
      );
      expect(
        (await remote.createOrganization(name: '  ')).failureOrNull?.kind,
        OrgFailureKind.invalidName,
      );
    });

    test('duplicate invite → duplicateMember on both', () async {
      final FakeOrganizationGateway fake = FakeOrganizationGateway();
      final _StubOrgApi stub = _StubOrgApi()
        ..error = const SupabaseOrgException(
          kind: SupabaseOrgFailureKind.duplicateMember,
          message: 'duplicate',
        );
      final SupabaseOrganizationGateway remote = SupabaseOrganizationGateway(
        stub,
      );

      // The fake rejects the demo member's own display name as already
      // present; the remote maps the provider duplicate arm.
      expect(
        (await fake.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'Demo user',
          role: UserRole.client,
        )).failureOrNull?.kind,
        OrgFailureKind.duplicateMember,
      );
      expect(
        (await remote.inviteMember(
          organizationId: 'org-remote',
          email: 'new@firm.com',
          role: UserRole.attorney,
        )).failureOrNull?.kind,
        OrgFailureKind.duplicateMember,
      );
    });

    test(
      'foreign-org roster read → denied on both (never empty-success)',
      () async {
        final FakeOrganizationGateway fake = FakeOrganizationGateway();
        final _StubOrgApi stub = _StubOrgApi()
          ..error = const SupabaseOrgException(
            kind: SupabaseOrgFailureKind.denied,
            message: 'permission denied',
          );
        final SupabaseOrganizationGateway remote = SupabaseOrganizationGateway(
          stub,
        );

        expect(
          (await fake.listMembers(
            organizationId: 'org-foreign',
          )).failureOrNull?.kind,
          OrgFailureKind.denied,
        );
        expect(
          (await remote.listMembers(
            organizationId: 'org-foreign',
          )).failureOrNull?.kind,
          OrgFailureKind.denied,
        );
      },
    );

    test('denial is never collapsed into unknown on the remote side', () async {
      final _StubOrgApi stub = _StubOrgApi()
        ..error = const SupabaseOrgException(
          kind: SupabaseOrgFailureKind.denied,
          message: 'permission denied',
        );
      final SupabaseOrganizationGateway remote = SupabaseOrganizationGateway(
        stub,
      );

      final OrgOutcome<void> outcome = await remote.suspendMember(
        organizationId: 'org-remote',
        userId: 'user-x',
      );
      expect(outcome.failureOrNull?.kind, OrgFailureKind.denied);
      expect(outcome.failureOrNull?.kind, isNot(OrgFailureKind.unknown));
    });
  });
}
