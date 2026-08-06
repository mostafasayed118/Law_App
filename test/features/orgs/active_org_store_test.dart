import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/data/local/in_memory_org_selection_store.dart';
import 'package:legalhub/data/local/org_selection_store.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';

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
}
