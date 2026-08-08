import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/orgs/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/presentation/org_cubit.dart';

/// A gateway that delays `createOrganization` behind a caller-opened gate so
/// tests can pin in-flight behavior; everything else delegates to the fake.
class _GatedOrgGateway implements OrganizationGateway {
  _GatedOrgGateway(this._inner);

  final OrganizationGateway _inner;
  Completer<void>? createGate;
  int createCalls = 0;

  @override
  Future<OrgOutcome<OrganizationSummary>> createOrganization({
    required String name,
  }) async {
    createCalls++;
    if (createGate != null) {
      await createGate!.future;
    }
    return _inner.createOrganization(name: name);
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers({
    required String organizationId,
  }) => _inner.listMembers(organizationId: organizationId);

  @override
  Future<OrgOutcome<InviteResult>> inviteMember({
    required String organizationId,
    required String email,
    required UserRole role,
  }) => _inner.inviteMember(
    organizationId: organizationId,
    email: email,
    role: role,
  );

  @override
  Future<OrgOutcome<void>> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) => _inner.changeMemberRole(
    organizationId: organizationId,
    userId: userId,
    role: role,
  );

  @override
  Future<OrgOutcome<void>> suspendMember({
    required String organizationId,
    required String userId,
  }) => _inner.suspendMember(organizationId: organizationId, userId: userId);

  @override
  Future<OrgOutcome<void>> reactivateMember({
    required String organizationId,
    required String userId,
  }) => _inner.reactivateMember(organizationId: organizationId, userId: userId);

  @override
  Future<OrgOutcome<void>> removeMember({
    required String organizationId,
    required String userId,
  }) => _inner.removeMember(organizationId: organizationId, userId: userId);

  @override
  Future<OrgOutcome<String>> resendInvitation({required String invitationId}) =>
      _inner.resendInvitation(invitationId: invitationId);

  @override
  Future<OrgOutcome<void>> revokeInvitation({required String invitationId}) =>
      _inner.revokeInvitation(invitationId: invitationId);

  @override
  Future<OrgOutcome<void>> deleteMyAccount() => _inner.deleteMyAccount();

  @override
  Future<OrgOutcome<String>> acceptInvitation({required String token}) =>
      _inner.acceptInvitation(token: token);

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) => _inner.readOrgAudit(organizationId: organizationId);
}

void main() {
  group('OrgCubit.createOrganization', () {
    test('emits loading then success and trims the name', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);
      expect(cubit.state, const OrgInitial());

      await cubit.createOrganization(name: '  Sterling & Co  ');

      final OrgCreateSuccess success = cubit.state as OrgCreateSuccess;
      expect(success.organization.name, 'Sterling & Co');
      expect(success.organization.id, isNotEmpty);
    });

    test('rejects an empty name with a typed invalidName failure', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      await cubit.createOrganization(name: '   ');

      final OrgCreateFailed failed = cubit.state as OrgCreateFailed;
      expect(failed.kind, OrgFailureKind.invalidName);
      expect(failed.error.code, 'org.invalidName');
    });

    test('ignores a second submit while one is in flight', () async {
      final _GatedOrgGateway gated = _GatedOrgGateway(
        FakeOrganizationGateway(),
      );
      final OrgCubit cubit = OrgCubit(gated);
      addTearDown(cubit.close);
      final Completer<void> gate = Completer<void>();
      gated.createGate = gate;

      final Future<void> first = cubit.createOrganization(name: 'First');
      final Future<void> second = cubit.createOrganization(name: 'Second');
      // The second submit is ignored while the first is in flight, so only
      // one call reaches the seam.
      expect(gated.createCalls, 1);
      expect(cubit.state, const OrgCreateLoading());

      gate.complete();
      await first;
      await second;
      expect(cubit.state, isA<OrgCreateSuccess>());
      expect((cubit.state as OrgCreateSuccess).organization.name, 'First');
    });
  });

  group('OrgCubit.loadRoster', () {
    test('emits loading then the loaded members', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      await cubit.loadRoster(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );

      final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
      expect(loaded.members, hasLength(1));
      expect(loaded.members.single.displayName, 'Demo user');
      expect(loaded.members.single.role, UserRole.partner);
      expect(loaded.members.single.status, MembershipStatus.active);
    });

    test('carries the failure kind and organization id for retry', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      await cubit.loadRoster(organizationId: 'org-unknown');

      final OrgRosterFailed failed = cubit.state as OrgRosterFailed;
      expect(failed.kind, OrgFailureKind.denied);
      expect(failed.organizationId, 'org-unknown');
    });

    test('recovers on retry after a failure', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      await cubit.loadRoster(organizationId: 'org-unknown');
      expect(cubit.state, isA<OrgRosterFailed>());

      await cubit.loadRoster(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      expect(cubit.state, isA<OrgRosterLoaded>());
    });
  });

  group('OrgCubit member actions', () {
    Future<OrgCubit> loadedCubit(FakeOrganizationGateway gateway) async {
      final OrgCubit cubit = OrgCubit(gateway);
      await cubit.loadRoster(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      expect(cubit.state, isA<OrgRosterLoaded>());
      return cubit;
    }

    test('suspending the last active partner returns lastPartner', () async {
      final OrgCubit cubit = await loadedCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.suspendMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
      );

      expect(kind, OrgFailureKind.lastPartner);
      final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
      expect(loaded.members.single.status, MembershipStatus.active);
      expect(loaded.pendingUserId, isNull);
    });

    test('changing the last partner role returns lastPartner', () async {
      final OrgCubit cubit = await loadedCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.changeMemberRole(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
        role: UserRole.client,
      );

      expect(kind, OrgFailureKind.lastPartner);
      expect(
        (cubit.state as OrgRosterLoaded).members.single.role,
        UserRole.partner,
      );
    });

    test('removing yourself returns denied', () async {
      final OrgCubit cubit = await loadedCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.removeMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: FakeOrganizationGateway.demoUserId,
      );

      expect(kind, OrgFailureKind.denied);
    });

    test(
      'a successful suspend reloads the roster with the new status',
      () async {
        final FakeOrganizationGateway gateway = FakeOrganizationGateway();
        await gateway.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'attorney@firm.com',
          role: UserRole.attorney,
        );
        final OrgCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        final OrgFailureKind? kind = await cubit.suspendMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'attorney@firm.com',
        );

        expect(kind, isNull);
        final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
        expect(loaded.members, hasLength(2));
        final OrgMember attorney = loaded.members.singleWhere(
          (OrgMember m) => m.userId == 'attorney@firm.com',
        );
        expect(attorney.status, MembershipStatus.suspended);
      },
    );

    test(
      'a successful role change reloads the roster with the new role',
      () async {
        final FakeOrganizationGateway gateway = FakeOrganizationGateway();
        await gateway.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'attorney@firm.com',
          role: UserRole.attorney,
        );
        final OrgCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        final OrgFailureKind? kind = await cubit.changeMemberRole(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'attorney@firm.com',
          role: UserRole.partner,
        );

        expect(kind, isNull);
        final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
        final OrgMember attorney = loaded.members.singleWhere(
          (OrgMember m) => m.userId == 'attorney@firm.com',
        );
        expect(attorney.role, UserRole.partner);
      },
    );

    test(
      'a successful reactivate reloads the roster with active status',
      () async {
        final FakeOrganizationGateway gateway = FakeOrganizationGateway();
        await gateway.inviteMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          email: 'attorney@firm.com',
          role: UserRole.attorney,
        );
        await gateway.suspendMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'attorney@firm.com',
        );
        final OrgCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        final OrgFailureKind? kind = await cubit.reactivateMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: 'attorney@firm.com',
        );

        expect(kind, isNull);
        final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
        final OrgMember attorney = loaded.members.singleWhere(
          (OrgMember m) => m.userId == 'attorney@firm.com',
        );
        expect(attorney.status, MembershipStatus.active);
      },
    );

    test(
      'a failed action restores the previous roster without a spinner',
      () async {
        final OrgCubit cubit = await loadedCubit(FakeOrganizationGateway());
        addTearDown(cubit.close);

        final OrgFailureKind? kind = await cubit.suspendMember(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          userId: FakeOrganizationGateway.demoUserId,
        );

        expect(kind, OrgFailureKind.lastPartner);
        final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
        expect(loaded.members, hasLength(1));
        expect(loaded.pendingUserId, isNull);
      },
    );

    test('actions are no-ops before the roster has loaded', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.removeMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        userId: 'someone-else',
      );

      expect(kind, isNull);
      expect(cubit.state, const OrgInitial());
    });
  });

  group('OrgCubit invite lifecycle (Phase 2)', () {
    Future<OrgCubit> cubitWithPendingInvite(
      FakeOrganizationGateway gateway,
    ) async {
      await gateway.inviteMember(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        email: 'attorney@firm.com',
        role: UserRole.attorney,
      );
      final OrgCubit cubit = OrgCubit(gateway);
      await cubit.loadRoster(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
      );
      expect(cubit.state, isA<OrgRosterLoaded>());
      return cubit;
    }

    OrgMember pendingMember(OrgRosterLoaded loaded) => loaded.members
        .singleWhere((OrgMember m) => m.userId == 'attorney@firm.com');

    test('resend returns the fresh token and refreshes the roster', () async {
      final FakeOrganizationGateway gateway = FakeOrganizationGateway();
      final OrgCubit cubit = await cubitWithPendingInvite(gateway);
      addTearDown(cubit.close);

      final OrgMember attorney = pendingMember(cubit.state as OrgRosterLoaded);
      expect(attorney.invitationId, 'inv-1');

      final OrgInviteActionResult result = await cubit.resendInvitation(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        invitationId: attorney.invitationId!,
        email: attorney.displayName,
      );

      final OrgInviteActionSuccess success = result as OrgInviteActionSuccess;
      expect(success.token, startsWith('demo-invite-token-resend-'));
      final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
      expect(loaded.members, hasLength(2));
      expect(loaded.pendingUserId, isNull);
    });

    test(
      'resend on an unknown invitation id returns invalidInvitation',
      () async {
        final FakeOrganizationGateway gateway = FakeOrganizationGateway();
        final OrgCubit cubit = await cubitWithPendingInvite(gateway);
        addTearDown(cubit.close);

        final OrgInviteActionResult result = await cubit.resendInvitation(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          invitationId: 'inv-unknown',
          email: 'attorney@firm.com',
        );

        final OrgInviteActionFailure failure = result as OrgInviteActionFailure;
        expect(failure.kind, OrgFailureKind.invalidInvitation);
        // The last good roster is restored with no row left pending.
        final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
        expect(loaded.members, hasLength(2));
        expect(loaded.pendingUserId, isNull);
      },
    );

    test('resend is a no-op before the roster has loaded', () async {
      final OrgCubit cubit = OrgCubit(FakeOrganizationGateway());
      addTearDown(cubit.close);

      final OrgInviteActionResult result = await cubit.resendInvitation(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        invitationId: 'inv-1',
        email: 'attorney@firm.com',
      );

      expect(result, isA<OrgInviteActionFailure>());
      expect(cubit.state, const OrgInitial());
    });

    test('revoke refreshes the roster without the revoked row', () async {
      final FakeOrganizationGateway gateway = FakeOrganizationGateway();
      final OrgCubit cubit = await cubitWithPendingInvite(gateway);
      addTearDown(cubit.close);

      final OrgMember attorney = pendingMember(cubit.state as OrgRosterLoaded);
      final OrgFailureKind? kind = await cubit.revokeInvitation(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        invitationId: attorney.invitationId!,
        email: attorney.displayName,
      );

      expect(kind, isNull);
      final OrgRosterLoaded loaded = cubit.state as OrgRosterLoaded;
      expect(loaded.members, hasLength(1));
      expect(
        loaded.members.any((OrgMember m) => m.userId == 'attorney@firm.com'),
        isFalse,
      );
    });

    test(
      'revoke on an unknown invitation id returns invalidInvitation',
      () async {
        final FakeOrganizationGateway gateway = FakeOrganizationGateway();
        final OrgCubit cubit = await cubitWithPendingInvite(gateway);
        addTearDown(cubit.close);

        final OrgFailureKind? kind = await cubit.revokeInvitation(
          organizationId: FakeOrganizationGateway.demoOrganizationId,
          invitationId: 'inv-unknown',
          email: 'attorney@firm.com',
        );

        expect(kind, OrgFailureKind.invalidInvitation);
        expect((cubit.state as OrgRosterLoaded).members, hasLength(2));
      },
    );

    test('a revoked invitation cannot be revoked again', () async {
      final FakeOrganizationGateway gateway = FakeOrganizationGateway();
      final OrgCubit cubit = await cubitWithPendingInvite(gateway);
      addTearDown(cubit.close);

      final OrgMember attorney = pendingMember(cubit.state as OrgRosterLoaded);
      await cubit.revokeInvitation(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        invitationId: attorney.invitationId!,
        email: attorney.displayName,
      );
      final OrgFailureKind? kind = await cubit.revokeInvitation(
        organizationId: FakeOrganizationGateway.demoOrganizationId,
        invitationId: attorney.invitationId!,
        email: attorney.displayName,
      );

      expect(kind, OrgFailureKind.invalidInvitation);
    });
  });
}
