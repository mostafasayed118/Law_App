part of 'fake_organization_gateway.dart';

/// The fake gateway's in-memory state, split out of the main class so
/// the invitation/admin method groups can live in library-private
/// mixins while sharing the exact same field instances.
class _FakeOrgState {
  final Map<String, OrganizationSummary> _orgs =
      <String, OrganizationSummary>{};
  final Map<String, Map<String, OrgMember>> _members =
      <String, Map<String, OrgMember>>{};
  final Map<String, List<AuditEntry>> _audit = <String, List<AuditEntry>>{};

  final Map<String, _FakeInvitation> _invitations = <String, _FakeInvitation>{};
  int _inviteCounter = 0;
}
