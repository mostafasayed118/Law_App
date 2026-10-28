import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/features/orgs/domain/organization_models.dart';

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
