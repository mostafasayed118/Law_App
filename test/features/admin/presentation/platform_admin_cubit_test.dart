import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/admin/platform_admin_gateway.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/admin/presentation/platform_admin_cubit.dart';

/// Hand-rolled stub of the [PlatformAdminGateway] seam: canned outcomes per
/// call, recorded call history, so the cubit's state machine is tested
/// without a provider.
class _StubPlatformAdminGateway implements PlatformAdminGateway {
  OrgOutcome<List<OrganizationSummary>> orgsOutcome =
      const OrgOutcome<List<OrganizationSummary>>.success(
        <OrganizationSummary>[],
      );
  OrgOutcome<List<OrgMember>> membersOutcome =
      const OrgOutcome<List<OrgMember>>.success(<OrgMember>[]);
  OrgOutcome<void> voidOutcome = const OrgOutcome<void>.success(null);
  final List<String> calls = <String>[];

  @override
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations() async {
    calls.add('orgs');
    return orgsOutcome;
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers() async {
    calls.add('members');
    return membersOutcome;
  }

  @override
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('suspend:$organizationId:$userId');
    return voidOutcome;
  }

  @override
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {
    calls.add('reactivate:$organizationId:$userId');
    return voidOutcome;
  }

  @override
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId}) async {
    calls.add('delete:$userId');
    return voidOutcome;
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readPlatformAudit() async {
    calls.add('platformAudit');
    return const OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[]);
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    calls.add('orgAudit:$organizationId');
    return const OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[]);
  }
}

final OrganizationSummary _org = OrganizationSummary(
  id: 'org-1',
  name: 'Demo Firm',
  createdAt: DateTime.utc(2026, 7, 25),
);

final OrgMember _member = OrgMember(
  organizationId: 'org-1',
  userId: 'u-1',
  displayName: 'Demo user',
  locale: 'en',
  role: UserRole.partner,
  status: MembershipStatus.active,
  createdAt: DateTime.utc(2026, 7, 25),
  updatedAt: DateTime.utc(2026, 7, 25),
);

void main() {
  group('PlatformAdminCubit.load', () {
    test('emits loading then both loaded lists', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgsOutcome = OrgOutcome<List<OrganizationSummary>>.success(
          <OrganizationSummary>[_org],
        )
        ..membersOutcome = OrgOutcome<List<OrgMember>>.success(<OrgMember>[
          _member,
        ]);
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);
      expect(cubit.state, const PlatformAdminInitial());

      await cubit.load();

      final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
      expect(loaded.organizations.single.name, 'Demo Firm');
      expect(loaded.members.single.userId, 'u-1');
      expect(loaded.pendingUserId, isNull);
      expect(gateway.calls, <String>['orgs', 'members']);
    });

    test('a non-owner denial becomes the distinct denied state, not empty '
        'success (AC-7)', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgsOutcome = const OrgOutcome<List<OrganizationSummary>>.failure(
          OrgFailure(kind: OrgFailureKind.denied),
        )
        ..membersOutcome = OrgOutcome<List<OrgMember>>.success(<OrgMember>[
          _member,
        ]);
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const PlatformAdminDenied());
    });

    test('a members denial also becomes the distinct denied state', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgsOutcome = OrgOutcome<List<OrganizationSummary>>.success(
          <OrganizationSummary>[_org],
        )
        ..membersOutcome = const OrgOutcome<List<OrgMember>>.failure(
          OrgFailure(kind: OrgFailureKind.denied),
        );
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const PlatformAdminDenied());
    });

    test('a non-denial failure emits the typed failure', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgsOutcome = const OrgOutcome<List<OrganizationSummary>>.failure(
          OrgFailure(kind: OrgFailureKind.unknown, message: 'boom'),
        );
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      await cubit.load();

      final PlatformAdminFailed failed = cubit.state as PlatformAdminFailed;
      expect(failed.kind, OrgFailureKind.unknown);
      expect(failed.error.code, 'platformAdmin.unknown');
    });

    test(
      'an honest empty owner result still renders the loaded empty state',
      () async {
        final PlatformAdminCubit cubit = PlatformAdminCubit(
          _StubPlatformAdminGateway(),
        );
        addTearDown(cubit.close);

        await cubit.load();

        final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
        expect(loaded.organizations, isEmpty);
        expect(loaded.members, isEmpty);
      },
    );
  });

  group('PlatformAdminCubit actions', () {
    Future<PlatformAdminCubit> loadedCubit(
      _StubPlatformAdminGateway gateway,
    ) async {
      gateway
        ..orgsOutcome = OrgOutcome<List<OrganizationSummary>>.success(
          <OrganizationSummary>[_org],
        )
        ..membersOutcome = OrgOutcome<List<OrgMember>>.success(<OrgMember>[
          _member,
        ]);
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      await cubit.load();
      expect(cubit.state, isA<PlatformAdminLoaded>());
      return cubit;
    }

    test('a successful suspend reloads both lists', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.suspendMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(kind, isNull);
      expect(gateway.calls, contains('suspend:org-1:u-2'));
      // Reload: two more list reads after the initial load.
      expect(
        gateway.calls.where((String c) => c == 'orgs' || c == 'members'),
        hasLength(4),
      );
      expect((cubit.state as PlatformAdminLoaded).pendingUserId, isNull);
    });

    test('a denied action returns denied and restores the lists', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..voidOutcome = const OrgOutcome<void>.failure(
          OrgFailure(kind: OrgFailureKind.denied),
        );
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.reactivateMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(kind, OrgFailureKind.denied);
      final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
      expect(loaded.organizations.single.id, 'org-1');
      expect(loaded.members.single.userId, 'u-1');
      expect(loaded.pendingUserId, isNull);
    });

    test('deleteDemoAccount success reloads and drops the row', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.deleteDemoAccount(userId: 'u-9');

      expect(kind, isNull);
      expect(gateway.calls, contains('delete:u-9'));
    });

    test('a never-self delete surfaces the typed denied', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..voidOutcome = const OrgOutcome<void>.failure(
          OrgFailure(kind: OrgFailureKind.denied),
        );
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.deleteDemoAccount(
        userId: 'demo-user',
      );

      expect(kind, OrgFailureKind.denied);
      expect((cubit.state as PlatformAdminLoaded).pendingUserId, isNull);
    });

    test('actions are no-ops before the lists have loaded', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      final OrgFailureKind? kind = await cubit.suspendMembership(
        organizationId: 'org-1',
        userId: 'u-2',
      );

      expect(kind, isNull);
      expect(cubit.state, const PlatformAdminInitial());
      expect(gateway.calls, isEmpty);
    });

    test('a second load is ignored while one is in flight', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      final Future<void> first = cubit.load();
      final Future<void> second = cubit.load();
      await first;
      await second;

      // The second submit is ignored: only one pair of list reads.
      expect(
        gateway.calls.where((String c) => c == 'orgs' || c == 'members'),
        hasLength(2),
      );
      expect(cubit.state, isA<PlatformAdminLoaded>());
    });
  });
}
