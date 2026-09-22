part of 'fake_organization_gateway.dart';

/// Library-private helpers shared by the gateway's method groups.
extension _FakeOrganizationGatewayHelpers on _FakeOrgState {
  bool _anotherActivePartnerExists(
    Map<String, OrgMember> roster,
    String userId,
  ) {
    for (final OrgMember member in roster.values) {
      if (member.userId != userId &&
          member.role == UserRole.partner &&
          member.isActive) {
        return true;
      }
    }
    return false;
  }

  String? _assignableRoleName(UserRole role) {
    return switch (role) {
      UserRole.client => 'client',
      UserRole.attorney => 'attorney',
      UserRole.partner => 'partner',
      _ => null,
    };
  }

  OrgMember _copy(
    OrgMember source, {
    UserRole? role,
    MembershipStatus? status,
  }) => OrgMember(
    organizationId: source.organizationId,
    userId: source.userId,
    displayName: source.displayName,
    locale: source.locale,
    role: role ?? source.role,
    status: status ?? source.status,
    createdAt: source.createdAt,
    updatedAt: DateTime.now(),
    invitationId: source.invitationId,
  );
}
