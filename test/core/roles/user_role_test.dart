import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/core/roles/user_role.dart';

void main() {
  group('UserRole', () {
    test('exposes the six product roles from INSTRUCTIONS §1.1', () {
      expect(UserRole.values, <UserRole>[
        UserRole.client,
        UserRole.attorney,
        UserRole.partner,
        UserRole.complianceOfficer,
        UserRole.researchAnalyst,
        UserRole.admin,
      ]);
    });
  });

  group('RoleCapability', () {
    test('is equatable on its capability flags', () {
      const RoleCapability a = RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
      );
      const RoleCapability b = RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
      );
      const RoleCapability c = RoleCapability(
        canViewHome: true,
        canViewSettings: false,
        canBookConsultation: false,
        canViewAttorneyDiscovery: false,
        canViewMatters: false,
        canViewDocuments: false,
        canViewMessages: false,
      );

      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });

  group('roleCapabilities', () {
    test('has an entry for every UserRole', () {
      for (final UserRole role in UserRole.values) {
        expect(roleCapabilities, contains(role));
      }
      expect(roleCapabilities.length, UserRole.values.length);
    });

    test(
      'grants home + settings + booking + discovery visibility to every role',
      () {
        // The bootstrap capability map is intentionally degenerate: every role
        // can see home + settings. This test pins that current-state contract
        // so a future role-differentiation change is a deliberate edit, not an
        // accident. Capabilities are navigation hints ONLY, not authorization
        // (see the doc comment in user_role.dart).
        for (final UserRole role in UserRole.values) {
          final RoleCapability cap = roleCapabilities[role]!;
          expect(cap.canViewHome, isTrue, reason: 'role $role');
          expect(cap.canViewSettings, isTrue, reason: 'role $role');
          // Phase 5 (D-B7 standalone): every bootstrap role also gets the
          // booking entry in the demo capability map.
          expect(cap.canBookConsultation, isTrue, reason: 'role $role');
          // Phase 6 (D-A6): discovery is visible to every bootstrap role —
          // navigation hint only, never authorization.
          expect(cap.canViewAttorneyDiscovery, isTrue, reason: 'role $role');
          // Phase 8 (D-V5): the vault entry is visible to every bootstrap
          // role — navigation hint only, never authorization.
          expect(cap.canViewDocuments, isTrue, reason: 'role $role');
          // Phase 9 (D-MSG5): the messaging entry is visible to every
          // bootstrap role — navigation hint only, never authorization.
          expect(cap.canViewMessages, isTrue, reason: 'role $role');
        }
      },
    );

    test('every role can reach at least one destination (shell invariant)', () {
      // _AppShell reads roleCapabilities[role]! and renders its bottom
      // NavigationBar only when at least two destinations are granted (Material
      // 3 asserts destinations.length >= 2). A role granting no destination
      // would be stranded with no navigation at all — the one state this map
      // must never contain. Pinned at the map level here so the shell contract
      // holds regardless of rendering behavior.
      for (final UserRole role in UserRole.values) {
        final RoleCapability cap = roleCapabilities[role]!;
        expect(
          cap.canViewHome || cap.canViewSettings,
          isTrue,
          reason: 'role $role must grant at least one destination',
        );
      }
    });

    test('every granted destination maps to a shell-rendered route', () {
      // _AppShell renders a bottom-NavigationBar destination for exactly two
      // routes: home and settings. A role granting a destination outside that
      // set would be a capability flag with no route behind it — dead at best,
      // a stranded navigation at worst. AppRoutes is the single source of
      // truth for route strings, so this pin survives path changes and fails
      // if the pairing ever drifts.
      const Set<String> shellDestinations = <String>{
        AppRoutes.home,
        AppRoutes.settings,
      };
      for (final UserRole role in UserRole.values) {
        final RoleCapability cap = roleCapabilities[role]!;
        final Set<String> granted = <String>{
          if (cap.canViewHome) AppRoutes.home,
          if (cap.canViewSettings) AppRoutes.settings,
        };
        expect(
          granted.difference(shellDestinations),
          isEmpty,
          reason: 'role $role grants a destination the shell does not render',
        );
      }
    });
  });
}
