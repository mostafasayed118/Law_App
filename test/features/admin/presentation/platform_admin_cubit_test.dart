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
  OrgOutcome<List<AuditEntry>> platformAuditOutcome =
      const OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[]);
  OrgOutcome<List<AuditEntry>> orgAuditOutcome =
      const OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[]);
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
    return platformAuditOutcome;
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    calls.add('orgAudit:$organizationId');
    return orgAuditOutcome;
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

  group('PlatformAdminCubit audit trail (T4, section-local)', () {
    final AuditEntry entry = AuditEntry(
      id: 1,
      action: 'member_invited',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-0002',
      redactedSummary: 'Member invited (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 26, 11, 30),
      actorUserId: 'u-1',
      organizationId: 'org-1',
    );

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

    test(
      'loadAudit fills the platform trail without touching the lists',
      () async {
        final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
          ..platformAuditOutcome = OrgOutcome<List<AuditEntry>>.success(
            <AuditEntry>[entry],
          );
        final PlatformAdminCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);
        expect(gateway.calls, isNot(contains('platformAudit')));

        await cubit.loadAudit();

        final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
        expect(loaded.platformAudit.single.id, 1);
        expect(loaded.organizations.single.id, 'org-1');
        expect(gateway.calls, contains('platformAudit'));
      },
    );

    test('loadAudit is a no-op before the lists have loaded', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      await cubit.loadAudit();

      expect(cubit.state, const PlatformAdminInitial());
      expect(gateway.calls, isEmpty);
    });

    test(
      'a denied audit read becomes the distinct denied state (AC-7)',
      () async {
        final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
          ..platformAuditOutcome = const OrgOutcome<List<AuditEntry>>.failure(
            OrgFailure(kind: OrgFailureKind.denied),
          );
        final PlatformAdminCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        await cubit.loadAudit();

        expect(cubit.state, const PlatformAdminDenied());
      },
    );

    test(
      'a non-denial audit failure surfaces the inline section error',
      () async {
        final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
          ..platformAuditOutcome = const OrgOutcome<List<AuditEntry>>.failure(
            OrgFailure(kind: OrgFailureKind.unknown, message: 'boom'),
          );
        final PlatformAdminCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        await cubit.loadAudit();

        final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
        expect(loaded.auditError, OrgFailureKind.unknown);
        // The loaded lists survive a section-local failure.
        expect(loaded.organizations.single.id, 'org-1');
        expect(loaded.members.single.userId, 'u-1');
      },
    );

    test('selectAuditOrg fetches and fills the org-scoped trail', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgAuditOutcome = OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[
          entry,
        ]);
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      await cubit.selectAuditOrg('org-1');

      final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
      expect(loaded.selectedAuditOrgId, 'org-1');
      expect(loaded.orgAudit.single.id, 1);
      expect(gateway.calls, contains('orgAudit:org-1'));
    });

    test('selectAuditOrg(null) clears the org trail without a fetch', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgAuditOutcome = OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[
          entry,
        ]);
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);
      await cubit.selectAuditOrg('org-1');
      expect((cubit.state as PlatformAdminLoaded).orgAudit, isNotEmpty);

      await cubit.selectAuditOrg(null);

      final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
      expect(loaded.selectedAuditOrgId, isNull);
      expect(loaded.orgAudit, isEmpty);
      expect(
        gateway.calls.where((String c) => c.startsWith('orgAudit')),
        hasLength(1),
      );
    });

    test(
      'a denied org audit read becomes the distinct denied state (AC-7)',
      () async {
        final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
          ..orgAuditOutcome = const OrgOutcome<List<AuditEntry>>.failure(
            OrgFailure(kind: OrgFailureKind.denied),
          );
        final PlatformAdminCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);

        await cubit.selectAuditOrg('org-1');

        expect(cubit.state, const PlatformAdminDenied());
      },
    );

    test('selectAuditOrg is a no-op before the lists have loaded', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway();
      final PlatformAdminCubit cubit = PlatformAdminCubit(gateway);
      addTearDown(cubit.close);

      await cubit.selectAuditOrg('org-1');

      expect(cubit.state, const PlatformAdminInitial());
      expect(gateway.calls, isEmpty);
    });

    test('a second loadAudit is ignored while one is in flight', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..platformAuditOutcome = OrgOutcome<List<AuditEntry>>.success(
          <AuditEntry>[entry],
        );
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final Future<void> first = cubit.loadAudit();
      final Future<void> second = cubit.loadAudit();
      await first;
      await second;

      // Only one platform audit read; the second submit is ignored.
      expect(
        gateway.calls.where((String c) => c == 'platformAudit'),
        hasLength(1),
      );
      expect((cubit.state as PlatformAdminLoaded).platformAudit, isNotEmpty);
    });

    test('a second selectAuditOrg is ignored while one is in flight', () async {
      final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
        ..orgAuditOutcome = OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[
          entry,
        ]);
      final PlatformAdminCubit cubit = await loadedCubit(gateway);
      addTearDown(cubit.close);

      final Future<void> first = cubit.selectAuditOrg('org-1');
      final Future<void> second = cubit.selectAuditOrg('org-1');
      await first;
      await second;

      expect(
        gateway.calls.where((String c) => c == 'orgAudit:org-1'),
        hasLength(1),
      );
      expect((cubit.state as PlatformAdminLoaded).orgAudit, isNotEmpty);
    });

    test(
      'the audit trail survives a list reload (action), never wiped',
      () async {
        final _StubPlatformAdminGateway gateway = _StubPlatformAdminGateway()
          ..platformAuditOutcome = OrgOutcome<List<AuditEntry>>.success(
            <AuditEntry>[entry],
          );
        final PlatformAdminCubit cubit = await loadedCubit(gateway);
        addTearDown(cubit.close);
        await cubit.loadAudit();
        expect((cubit.state as PlatformAdminLoaded).platformAudit, isNotEmpty);

        await cubit.load();

        final PlatformAdminLoaded loaded = cubit.state as PlatformAdminLoaded;
        expect(loaded.platformAudit.single.id, 1);
        expect(loaded.organizations.single.id, 'org-1');
        // The in-flight flag is never carried forward: the remounted Audit
        // section re-triggers its own fetch (reviewer finding, audit T4).
        expect(loaded.auditLoading, isFalse);
      },
    );
  });
}
