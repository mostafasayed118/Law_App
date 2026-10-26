import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/organizations/organization_models.dart';
import 'package:legalhub/core/roles/user_role.dart';

void main() {
  group('userRoleFromServerName', () {
    test('maps every server org_role to its domain role', () {
      expect(userRoleFromServerName('client'), UserRole.client);
      expect(userRoleFromServerName('attorney'), UserRole.attorney);
      expect(userRoleFromServerName('partner'), UserRole.partner);
      expect(
        userRoleFromServerName('compliance_officer'),
        UserRole.complianceOfficer,
      );
    });

    test('returns null for unknown or missing server names', () {
      expect(userRoleFromServerName('researchAnalyst'), isNull);
      expect(userRoleFromServerName('admin'), isNull);
      expect(userRoleFromServerName(null), isNull);
    });
  });
}
