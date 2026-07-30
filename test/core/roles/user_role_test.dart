import 'package:flutter_test/flutter_test.dart';
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
      );
      const RoleCapability b = RoleCapability(
        canViewHome: true,
        canViewSettings: true,
      );
      const RoleCapability c = RoleCapability(
        canViewHome: true,
        canViewSettings: false,
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

    test('grants home + settings visibility to every role in the bootstrap', () {
      // The bootstrap capability map is intentionally degenerate: every role
      // can see home + settings. This test pins that current-state contract
      // so a future role-differentiation change is a deliberate edit, not an
      // accident. Capabilities are navigation hints ONLY, not authorization
      // (see the doc comment in user_role.dart).
      for (final UserRole role in UserRole.values) {
        final RoleCapability cap = roleCapabilities[role]!;
        expect(cap.canViewHome, isTrue, reason: 'role $role');
        expect(cap.canViewSettings, isTrue, reason: 'role $role');
      }
    });
  });
}
