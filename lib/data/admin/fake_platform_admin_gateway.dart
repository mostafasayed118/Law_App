import '../../core/admin/platform_admin_gateway.dart';
import '../orgs/fake_organization_gateway.dart';

/// Development-only platform-admin implementation.
///
/// This class is a seam for presentation tests and env-less runs; it is not
/// an authorization mechanism and must not be used as production authority.
/// It mirrors the signed server semantics (P3.5): the owner-only RPCs gate
/// on `is_platform_owner()` server-side, so this fake gates the demo actor
/// on [demoIsPlatformOwner] — owner → metadata rows; non-owner → the typed
/// [OrgFailureKind.denied], never an empty success (AC-7).
///
/// State derives from the SHARED [FakeOrganizationGateway] instance (the
/// D-P33.2 one-instance DI pattern), so orgs created during an env-less run
/// appear in the admin lists. `deleteDemoAccount` refuses the demo identity,
/// mirroring the RPC's never-self guard (`cannot delete your own account`).
///
/// Known dev-only divergence (documented, not fixed): suspend/reactivate
/// delegate to the org fake, which enforces the last-active-partner guard —
/// `suspend_membership_platform` has no such guard server-side. Stricter
/// than the server is safe for a seam (it never over-grants), but a test
/// pinning "platform may suspend the last partner" would need the real RPC.
class FakePlatformAdminGateway implements PlatformAdminGateway {
  FakePlatformAdminGateway({
    FakeOrganizationGateway? organizationGateway,
    this.demoIsPlatformOwner = true,
  }) : _organizationGateway = organizationGateway ?? FakeOrganizationGateway();

  final FakeOrganizationGateway _organizationGateway;

  /// Mirrors `is_platform_owner()` for the demo actor. Defaults to true so
  /// env-less runs render metadata; tests flip it to pin the AC-7
  /// non-owner-denied path.
  final bool demoIsPlatformOwner;

  @override
  Future<OrgOutcome<List<OrganizationSummary>>> listOrganizations() async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<List<OrganizationSummary>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<OrganizationSummary>>.success(
      _organizationGateway.allOrganizations(),
    );
  }

  @override
  Future<OrgOutcome<List<OrgMember>>> listMembers() async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<List<OrgMember>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<OrgMember>>.success(
      _organizationGateway.allMembers(),
    );
  }

  @override
  Future<OrgOutcome<void>> suspendMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    // Delegate to the shared org fake: any-org semantics, with the
    // last-active-partner guard mirrored from the server.
    return _organizationGateway.suspendMember(
      organizationId: organizationId,
      userId: userId,
    );
  }

  @override
  Future<OrgOutcome<void>> reactivateMembership({
    required String organizationId,
    required String userId,
  }) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return _organizationGateway.reactivateMember(
      organizationId: organizationId,
      userId: userId,
    );
  }

  @override
  Future<OrgOutcome<void>> deleteDemoAccount({required String userId}) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    if (userId == FakeOrganizationGateway.demoUserId) {
      // Mirrors the RPC's never-self refusal; self-deletion goes through
      // `delete_my_account` on the organization surface.
      return const OrgOutcome<void>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    _organizationGateway.deleteAccount(userId);
    return const OrgOutcome<void>.success(null);
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readPlatformAudit() async {
    if (!demoIsPlatformOwner) {
      // AC-7: a non-owner is denied, never an empty success.
      return const OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    return OrgOutcome<List<AuditEntry>>.success(_platformAuditRows);
  }

  @override
  Future<OrgOutcome<List<AuditEntry>>> readOrgAudit({
    required String organizationId,
  }) async {
    if (!demoIsPlatformOwner) {
      return const OrgOutcome<List<AuditEntry>>.failure(
        OrgFailure(kind: OrgFailureKind.denied),
      );
    }
    // The fake is org-scoped to the demo org; a foreign org id reads as an
    // honest empty trail (metadata-only, no fabricated rows).
    if (organizationId != FakeOrganizationGateway.demoOrganizationId) {
      return const OrgOutcome<List<AuditEntry>>.success(<AuditEntry>[]);
    }
    return OrgOutcome<List<AuditEntry>>.success(_orgAuditRows);
  }

  /// Deterministic synthetic non-PII platform audit trail (5 rows, the
  /// D-AUD5 pattern). Fixed ids + correlation ids + timestamps so tests and
  /// env-less runs are stable; no credentials or content ever (contract §8).
  static final List<AuditEntry> _platformAuditRows = <AuditEntry>[
    AuditEntry(
      id: 1,
      action: 'organization_created',
      outcome: 'succeeded',
      resourceType: 'organization',
      resourceId: FakeOrganizationGateway.demoOrganizationId,
      correlationId: 'audit-0001',
      redactedSummary: 'Organization created (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 25, 10, 0),
      actorUserId: FakeOrganizationGateway.demoUserId,
      organizationId: FakeOrganizationGateway.demoOrganizationId,
    ),
    AuditEntry(
      id: 2,
      action: 'member_invited',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-0002',
      redactedSummary: 'Member invited (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 26, 11, 30),
      actorUserId: FakeOrganizationGateway.demoUserId,
      organizationId: FakeOrganizationGateway.demoOrganizationId,
    ),
    AuditEntry(
      id: 3,
      action: 'member_role_changed',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-0003',
      redactedSummary: 'Member role changed (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 27, 9, 15),
      actorUserId: FakeOrganizationGateway.demoUserId,
      organizationId: FakeOrganizationGateway.demoOrganizationId,
    ),
    AuditEntry(
      id: 4,
      action: 'membership_suspended',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-0004',
      redactedSummary: 'Membership suspended (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 28, 14, 45),
      actorUserId: FakeOrganizationGateway.demoUserId,
      organizationId: FakeOrganizationGateway.demoOrganizationId,
    ),
    AuditEntry(
      id: 5,
      action: 'demo_account_deleted',
      outcome: 'succeeded',
      resourceType: 'user',
      correlationId: 'audit-0005',
      redactedSummary: 'Demo account deleted (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 29, 16, 20),
      actorUserId: FakeOrganizationGateway.demoUserId,
      organizationId: FakeOrganizationGateway.demoOrganizationId,
    ),
  ];

  /// Deterministic synthetic non-PII org-scoped trail (3 rows, the demo
  /// org only).
  static final List<AuditEntry> _orgAuditRows = <AuditEntry>[
    AuditEntry(
      id: 1,
      action: 'organization_created',
      outcome: 'succeeded',
      resourceType: 'organization',
      correlationId: 'audit-1001',
      redactedSummary: 'Organization created (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 25, 10, 0),
    ),
    AuditEntry(
      id: 2,
      action: 'member_invited',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-1002',
      redactedSummary: 'Member invited (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 26, 11, 30),
    ),
    AuditEntry(
      id: 3,
      action: 'member_role_changed',
      outcome: 'succeeded',
      resourceType: 'membership',
      correlationId: 'audit-1003',
      redactedSummary: 'Member role changed (metadata only)',
      serverTimestamp: DateTime.utc(2026, 7, 27, 9, 15),
    ),
  ];
}
