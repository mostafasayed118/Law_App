import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/auth/auth_outcome.dart';
import 'package:legalhub/core/auth/session.dart';
import 'package:legalhub/core/roles/user_role.dart';

Session _session({
  String userId = 'user-1',
  String displayName = 'Amina',
  List<OrganizationMembership>? memberships,
  DateTime? expiresAt,
}) {
  return Session(
    userId: userId,
    displayName: displayName,
    memberships:
        memberships ??
        const <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-a',
            organizationName: 'Org A',
            role: UserRole.attorney,
            status: MembershipStatus.active,
          ),
        ],
    expiresAt: expiresAt ?? DateTime(2030, 1, 1),
  );
}

void main() {
  group('Session (contract §5 shape)', () {
    test('carries userId, displayName, memberships, and expiresAt', () {
      final Session session = _session(
        userId: 'user-42',
        displayName: 'Mostafa',
        memberships: const <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-b',
            organizationName: 'Org B',
            role: UserRole.partner,
            status: MembershipStatus.active,
          ),
        ],
        expiresAt: DateTime(2027, 6, 1),
      );

      expect(session.userId, 'user-42');
      expect(session.displayName, 'Mostafa');
      expect(session.memberships, hasLength(1));
      expect(session.memberships.single.organizationId, 'org-b');
      expect(session.expiresAt, DateTime(2027, 6, 1));
    });

    test(
      'has no single client-owned role — the role lives in a membership',
      () {
        // Contract §5 / D-T4 resolution: the session must not carry one
        // client-controlled `role` as the authority. The only role reachable is
        // the active membership's org-scoped role, projected for UX.
        final Session session = _session();
        expect(session.primaryRole, UserRole.attorney);
        expect(session.activeMembership?.role, UserRole.attorney);
      },
    );

    test('activeMembership returns the first active membership only', () {
      final Session session = _session(
        memberships: const <OrganizationMembership>[
          OrganizationMembership(
            organizationId: 'org-a',
            organizationName: 'Org A',
            role: UserRole.client,
            status: MembershipStatus.invited,
          ),
          OrganizationMembership(
            organizationId: 'org-b',
            organizationName: 'Org B',
            role: UserRole.attorney,
            status: MembershipStatus.active,
          ),
        ],
      );

      expect(session.activeMembership?.organizationId, 'org-b');
      expect(session.primaryRole, UserRole.attorney);
    });

    test(
      'activeMembership is null and primaryRole is null with no active membership',
      () {
        final Session session = _session(
          memberships: const <OrganizationMembership>[
            OrganizationMembership(
              organizationId: 'org-a',
              organizationName: 'Org A',
              role: UserRole.client,
              status: MembershipStatus.suspended,
            ),
            OrganizationMembership(
              organizationId: 'org-b',
              organizationName: 'Org B',
              role: UserRole.client,
              status: MembershipStatus.removed,
            ),
          ],
        );

        expect(session.activeMembership, isNull);
        expect(session.primaryRole, isNull);
      },
    );

    test('isExpired reflects the expiresAt boundary', () {
      expect(_session(expiresAt: DateTime(2020, 1, 1)).isExpired, isTrue);
      expect(_session(expiresAt: DateTime(2035, 1, 1)).isExpired, isFalse);
    });
  });

  group('OrganizationMembership', () {
    test('isActive reflects the lifecycle status', () {
      const OrganizationMembership active = OrganizationMembership(
        organizationId: 'org-a',
        organizationName: 'Org A',
        role: UserRole.admin,
        status: MembershipStatus.active,
      );
      const OrganizationMembership suspended = OrganizationMembership(
        organizationId: 'org-a',
        organizationName: 'Org A',
        role: UserRole.admin,
        status: MembershipStatus.suspended,
      );

      expect(active.isActive, isTrue);
      expect(suspended.isActive, isFalse);
    });

    test('MembershipStatus exposes the contract lifecycle states', () {
      expect(MembershipStatus.values, <MembershipStatus>[
        MembershipStatus.invited,
        MembershipStatus.active,
        MembershipStatus.suspended,
        MembershipStatus.removed,
      ]);
    });
  });

  group('AuthOutcome and AuthFailure', () {
    test('success carries the value', () {
      const AuthOutcome<String> outcome = AuthOutcome<String>.success('ok');

      expect(outcome.isSuccess, isTrue);
      expect(outcome.valueOrNull, 'ok');
      expect(outcome.failureOrNull, isNull);
    });

    test('failure carries the typed AuthFailure', () {
      const AuthFailure failure = AuthFailure(
        kind: AuthFailureKind.sessionExpired,
      );
      const AuthOutcome<String> outcome = AuthOutcome<String>.failure(failure);

      expect(outcome.isSuccess, isFalse);
      expect(outcome.valueOrNull, isNull);
      expect(outcome.failureOrNull, failure);
    });

    test(
      'AuthFailure carries only kind + message — no PII/credential context',
      () {
        // Privacy-by-design boundary (contract §8 / gate3 §3.2): the typed
        // failure that crosses the seam must not be a vehicle for passwords,
        // tokens, reset codes, or PII. Its Equatable props are exactly
        // [kind, message].
        const AuthFailure failure = AuthFailure(
          kind: AuthFailureKind.invalidCredentials,
          message: 'Invalid email or password',
        );

        expect(failure.props, <Object?>[
          AuthFailureKind.invalidCredentials,
          'Invalid email or password',
        ]);
      },
    );
  });
}
