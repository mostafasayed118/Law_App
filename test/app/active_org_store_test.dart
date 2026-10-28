import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/core/observability/error_reporter.dart';
import 'package:legalhub/core/persistence/in_memory_org_selection_store.dart';
import 'package:legalhub/core/persistence/org_selection_store.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/auth/domain/auth_gateway.dart';
import 'package:legalhub/features/auth/presentation/auth_cubit.dart';
import 'package:legalhub/features/orgs/data/fake_organization_gateway.dart';
import 'package:legalhub/features/orgs/domain/membership_repository.dart';

/// OrgSelectionStore whose read/write can be forced to fail, proving the
/// store degrades gracefully (persistence is best-effort UX context, D-08).
class _FlakyOrgSelectionStore implements OrgSelectionStore {
  _FlakyOrgSelectionStore({this.failRead = false, this.failWrite = false});

  final bool failRead;
  final bool failWrite;
  String? stored;

  @override
  Future<String?> read() async {
    if (failRead) {
      throw StateError('read boom');
    }
    return stored;
  }

  @override
  Future<void> write(String organizationId) async {
    if (failWrite) {
      throw StateError('write boom');
    }
    stored = organizationId;
  }
}

/// A gateway mirroring the real provider seam ([SupabaseAuthGateway]):
/// the sign-in snapshot carries **no memberships** (hydration is orchestrated
/// above the seam) and every explicit operation is announced on
/// [sessionChanges].
class _ProviderSnapshotGateway implements AuthGateway {
  @override
  Future<bool> startGoogleSignIn() async => false;

  final String userId = 'user-1';
  Session? _session;
  bool _recoveryPending = false;
  final StreamController<Session?> _changes =
      StreamController<Session?>.broadcast(sync: true);

  @override
  Session? get currentSession => _session;

  @override
  Stream<Session?> get sessionChanges => _changes.stream;

  @override
  bool get recoveryPending => _recoveryPending;

  @override
  bool get supportsDemoSession => false;

  @override
  Future<AuthOutcome<Session>> restore() async {
    final Session? session = _session;
    if (session == null) {
      return const AuthOutcome<Session>.failure(
        AuthFailure(kind: AuthFailureKind.signedOut),
      );
    }
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<AuthOutcome<Session>> signIn({
    required String email,
    required String password,
  }) async {
    final Session session = Session(
      userId: userId,
      displayName: 'qa-device-131043',
      // The provider snapshot never carries memberships (P3.2 by design).
      memberships: const <OrganizationMembership>[],
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
    _session = session;
    _changes.add(session);
    return AuthOutcome<Session>.success(session);
  }

  @override
  Future<AuthOutcome<Session>> startDemoSession() async {
    return const AuthOutcome<Session>.failure(
      AuthFailure(kind: AuthFailureKind.membershipDenied),
    );
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _recoveryPending = false;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

/// The membership read the live backend answers with: the caller's own
/// `memberships` rows (RLS-scoped). The list is the server truth at that
/// moment — empty before the organization is created, the created row after.
class _LiveMembershipRepository implements MembershipRepository {
  List<OrganizationMembership> memberships = const <OrganizationMembership>[];
  int calls = 0;

  @override
  Future<MembershipHydrationResult> loadMemberships({
    required String userId,
  }) async {
    calls += 1;
    return HydrationSucceeded(memberships);
  }
}

void main() {
  OrganizationMembership membership(String id, {String name = 'Org'}) =>
      OrganizationMembership(
        organizationId: id,
        organizationName: name,
        role: UserRole.partner,
        status: MembershipStatus.active,
      );

  Session sessionWith(
    List<OrganizationMembership> memberships, {
    String userId = 'user-1',
  }) => Session(
    userId: userId,
    displayName: 'Ada',
    memberships: memberships,
    expiresAt: DateTime.now().add(const Duration(hours: 8)),
  );

  ActiveOrgStore storeWith([OrgSelectionStore? selectionStore]) =>
      ActiveOrgStore(selectionStore ?? InMemoryOrgSelectionStore());

  group('ActiveOrgStore (Phase 7 slice 7.0, D-08/D-M7; P3.2 D-P32.2)', () {
    test('is empty before any session', () {
      final ActiveOrgStore store = storeWith();

      expect(store.activeOrganizationId, isNull);
    });

    test('seeds from Session.activeMembership (D-08 default)', () {
      final ActiveOrgStore store = storeWith();

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a', name: 'Firm A'),
          membership('org-b', name: 'Firm B'),
        ]),
      );

      expect(store.activeOrganizationId, 'org-a');
    });

    test('clears on sign-out (null session)', () {
      final ActiveOrgStore store = storeWith();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );

      store.syncFromSession(null);

      expect(store.activeOrganizationId, isNull);
    });

    test('a user selection persists within the same session', () {
      final ActiveOrgStore store = storeWith();
      final Session session = sessionWith(<OrganizationMembership>[
        membership('org-a'),
        membership('org-b'),
      ]);
      store.syncFromSession(session);

      store.select('org-b');
      store.syncFromSession(session);

      // Re-seeding the same session must not clobber the selection.
      expect(store.activeOrganizationId, 'org-b');
    });

    test('a selection made before the first seed survives that seed '
        '(P3.4 accept flow)', () {
      final ActiveOrgStore store = storeWith();

      // The accept screen selects before the hub ever seeds this session.
      store.select('org-b');
      expect(store.activeOrganizationId, 'org-b');

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );

      // The membership-backed selection wins over the session default.
      expect(store.activeOrganizationId, 'org-b');
    });

    test('a pre-seed selection the session does not hold falls back', () {
      final ActiveOrgStore store = storeWith();

      store.select('org-x');
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );

      // Foreign selection is never applied — the session is the authority.
      expect(store.activeOrganizationId, 'org-a');
    });

    test('a pre-seed selection does not carry into a different user', () {
      final ActiveOrgStore store = storeWith();

      store.select('org-b');
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      expect(store.activeOrganizationId, 'org-b');

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-c'),
        ], userId: 'user-2'),
      );

      // The accept selection is consumed by the first seed — a different
      // identity re-derives from its own session.
      expect(store.activeOrganizationId, 'org-c');
    });

    test('re-seeds when the session identity changes (new user)', () {
      final ActiveOrgStore store = storeWith();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      store.select('org-b');

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-c', name: 'Firm C'),
        ], userId: 'user-2'),
      );

      expect(store.activeOrganizationId, 'org-c');
    });

    test('notifies listeners on select', () {
      final ActiveOrgStore store = storeWith();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );
      int notifications = 0;
      store.addListener(() => notifications++);

      store.select('org-b');

      expect(store.activeOrganizationId, 'org-b');
      expect(notifications, 1);
    });

    test('selecting the current id is a no-op (no notification)', () {
      final ActiveOrgStore store = storeWith();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );
      int notifications = 0;
      store.addListener(() => notifications++);

      store.select('org-a');

      expect(notifications, 0);
    });

    test(
      'select persists the selection through the OrgSelectionStore',
      () async {
        final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
        final ActiveOrgStore store = ActiveOrgStore(prefs);
        store.syncFromSession(
          sessionWith(<OrganizationMembership>[membership('org-a')]),
        );

        store.select('org-b');
        await pumpEventQueue();

        expect(store.activeOrganizationId, 'org-b');
        expect(await prefs.read(), 'org-b');
      },
    );

    test('restores a persisted selection when the session holds it', () async {
      final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
      await prefs.write('org-b');
      final ActiveOrgStore store = ActiveOrgStore(prefs);
      await pumpEventQueue();

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );

      // The persisted selection wins over the session default (org-a).
      expect(store.activeOrganizationId, 'org-b');
    });

    test(
      'never applies a persisted selection the session does not hold',
      () async {
        final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
        await prefs.write('org-x');
        final ActiveOrgStore store = ActiveOrgStore(prefs);
        await pumpEventQueue();

        store.syncFromSession(
          sessionWith(<OrganizationMembership>[
            membership('org-a'),
            membership('org-b'),
          ]),
        );

        // Stale/foreign persisted id is ignored — the session is the authority.
        expect(store.activeOrganizationId, 'org-a');
      },
    );

    test('a persisted selection is applied only once per restore', () async {
      final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
      await prefs.write('org-b');
      final ActiveOrgStore store = ActiveOrgStore(prefs);
      await pumpEventQueue();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      expect(store.activeOrganizationId, 'org-b');

      // A later identity seed in the same process re-derives from the session
      // default; the persisted value is not re-applied forever.
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ], userId: 'user-2'),
      );

      expect(store.activeOrganizationId, 'org-a');
    });

    test('applies a persisted selection when the read resolves late', () async {
      final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
      await prefs.write('org-b');
      final ActiveOrgStore store = ActiveOrgStore(prefs);

      // The cold-start ordering: the hub seeds during the same build pass
      // the store is constructed, before the constructor-fired read resolves.
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      expect(store.activeOrganizationId, 'org-a');

      // The read resolves → the persisted selection is applied for this user.
      await pumpEventQueue();
      expect(store.activeOrganizationId, 'org-b');
    });

    test('a sign-out does not discard a restore that resolves later', () async {
      final InMemoryOrgSelectionStore prefs = InMemoryOrgSelectionStore();
      await prefs.write('org-b');
      final ActiveOrgStore store = ActiveOrgStore(prefs);

      // Seed and sign out before the constructor-fired read resolves.
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );
      store.syncFromSession(null);
      expect(store.activeOrganizationId, isNull);

      // The read resolves after sign-out → cached, not discarded…
      await pumpEventQueue();

      // …and the same user's re-sign-in re-validates and applies it.
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      expect(store.activeOrganizationId, 'org-b');
    });

    test('a write failure does not break the in-memory selection', () async {
      final _FlakyOrgSelectionStore prefs = _FlakyOrgSelectionStore(
        failWrite: true,
      );
      final ActiveOrgStore store = ActiveOrgStore(prefs);
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );

      store.select('org-b');
      await pumpEventQueue();

      expect(store.activeOrganizationId, 'org-b');
    });

    test('a read failure is treated as no persisted selection', () async {
      final _FlakyOrgSelectionStore prefs = _FlakyOrgSelectionStore(
        failRead: true,
      );
      final ActiveOrgStore store = ActiveOrgStore(prefs);
      await pumpEventQueue();

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );

      expect(store.activeOrganizationId, 'org-a');
    });
  });

  group('W1 F3 — the active organization survives a same-user re-auth', () {
    /// Replays the device sequence
    /// (docs/device_e2e_2026-10-21_c835ced.md, finding 3) at the seam level:
    ///
    /// 1. sign in → the user has no organization yet;
    /// 2. create the organization → the membership row exists server-side and
    ///    the hub refreshes the memberships in the background
    ///    ([AuthCubit.hydrate]);
    /// 3. sign out → the router redirects to sign-in and the hub leaves the
    ///    screen, so the store is never told the session went away;
    /// 4. sign in again as the **same** user.
    ///
    /// The hub seeds the store on every build
    /// (organization_hub_screen.dart:79) — that is the call modelled here.
    Future<void> replayDeviceSequence({
      required AuthCubit cubit,
      required ActiveOrgStore store,
      required _LiveMembershipRepository memberships,
    }) async {
      await cubit.signIn(
        email: 'qa-device-131043@legalhub.test',
        password: 'test-only-password',
      );
      store.syncFromSession(cubit.state.session);
      expect(store.activeOrganizationId, isNull);

      // The organization is created: the row exists on the server now.
      memberships.memberships = <OrganizationMembership>[
        membership('org-a', name: 'QA Device Firm'),
      ];
      await cubit.hydrate();
      store.syncFromSession(cubit.state.session);

      await cubit.signOut();
      expect(cubit.state.session, isNull);

      await cubit.signIn(
        email: 'qa-device-131043@legalhub.test',
        password: 'test-only-password',
      );
      store.syncFromSession(cubit.state.session);
    }

    AuthCubit cubitWith(_LiveMembershipRepository memberships) => AuthCubit(
      _ProviderSnapshotGateway(),
      InMemoryErrorReporter(),
      memberships,
      FakeOrganizationGateway(),
    );

    test('probe: the same-user re-auth hydrates the membership (candidate A '
        'refuted)', () async {
      final _LiveMembershipRepository memberships = _LiveMembershipRepository();
      final AuthCubit cubit = cubitWith(memberships);
      addTearDown(cubit.close);
      final ActiveOrgStore store = ActiveOrgStore(InMemoryOrgSelectionStore());

      await replayDeviceSequence(
        cubit: cubit,
        store: store,
        memberships: memberships,
      );

      // The membership read answers with the created row — the defect is
      // not in the hydration read.
      expect(cubit.state.session!.memberships, hasLength(1));
      expect(cubit.state.session!.activeMembership!.organizationId, 'org-a');
    });

    test('the active organization survives the same-user re-auth', () async {
      final _LiveMembershipRepository memberships = _LiveMembershipRepository();
      final AuthCubit cubit = cubitWith(memberships);
      addTearDown(cubit.close);
      final ActiveOrgStore store = ActiveOrgStore(InMemoryOrgSelectionStore());
      int notifications = 0;
      store.addListener(() => notifications++);

      await replayDeviceSequence(
        cubit: cubit,
        store: store,
        memberships: memberships,
      );

      // The hub must not render the "Create Organization" form again.
      expect(store.activeOrganizationId, 'org-a');
      // Re-seeding is a silent context update (no notification).
      expect(notifications, 0);
    });

    test(
      'a fresh store seeds the same session (the device restart fixes it)',
      () async {
        final _LiveMembershipRepository memberships =
            _LiveMembershipRepository();
        final AuthCubit cubit = cubitWith(memberships);
        addTearDown(cubit.close);
        final ActiveOrgStore store = ActiveOrgStore(
          InMemoryOrgSelectionStore(),
        );

        await replayDeviceSequence(
          cubit: cubit,
          store: store,
          memberships: memberships,
        );

        // A cold start builds a fresh store — it seeds the very same session.
        final ActiveOrgStore fresh = ActiveOrgStore(
          InMemoryOrgSelectionStore(),
        );
        fresh.syncFromSession(cubit.state.session);
        expect(fresh.activeOrganizationId, 'org-a');
      },
    );

    test('an explicit selection survives a membership-set change', () {
      final ActiveOrgStore store = ActiveOrgStore(InMemoryOrgSelectionStore());
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
        ]),
      );
      store.select('org-b');

      // The session gains a membership (a background refresh).
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a'),
          membership('org-b'),
          membership('org-c'),
        ]),
      );

      // The user's own selection is never dropped by a re-seed.
      expect(store.activeOrganizationId, 'org-b');
    });
  });
}
