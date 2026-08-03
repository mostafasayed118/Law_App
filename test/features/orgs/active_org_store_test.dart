import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/orgs/presentation/active_org_store.dart';

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

  group('ActiveOrgStore (Phase 7 slice 7.0, D-08/D-M7)', () {
    test('is empty before any session', () {
      final ActiveOrgStore store = ActiveOrgStore();

      expect(store.activeOrganizationId, isNull);
    });

    test('seeds from Session.activeMembership (D-08 default)', () {
      final ActiveOrgStore store = ActiveOrgStore();

      store.syncFromSession(
        sessionWith(<OrganizationMembership>[
          membership('org-a', name: 'Firm A'),
          membership('org-b', name: 'Firm B'),
        ]),
      );

      expect(store.activeOrganizationId, 'org-a');
    });

    test('clears on sign-out (null session)', () {
      final ActiveOrgStore store = ActiveOrgStore();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );

      store.syncFromSession(null);

      expect(store.activeOrganizationId, isNull);
    });

    test('a user selection persists within the same session', () {
      final ActiveOrgStore store = ActiveOrgStore();
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
      final ActiveOrgStore store = ActiveOrgStore();
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
      final ActiveOrgStore store = ActiveOrgStore();
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
      final ActiveOrgStore store = ActiveOrgStore();
      store.syncFromSession(
        sessionWith(<OrganizationMembership>[membership('org-a')]),
      );
      int notifications = 0;
      store.addListener(() => notifications++);

      store.select('org-a');

      expect(notifications, 0);
    });
  });
}
