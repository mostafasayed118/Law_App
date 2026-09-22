import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/admin/platform_admin_gateway.dart';
import '../../../core/errors/app_error.dart';
part 'platform_admin_state.dart';
part 'platform_admin_cubit_base.dart';
part 'platform_admin_cubit_audit.dart';

/// Owns the platform-admin surface against the [PlatformAdminGateway] seam.
///
/// The server is the authority (P3.5): the client never claims ownership —
/// both metadata RPCs are owner-gated server-side, and a denial from either
/// becomes the distinct [PlatformAdminDenied]. Actions (platform
/// suspend/reactivate, delete demo account) call the seam and reload both
/// lists on success; failures restore the last good lists and return the
/// typed [OrgFailureKind] so the screen can surface a localized message.
///
/// The audit trail is loaded section-locally: [loadAudit] (platform trail)
/// and [selectAuditOrg] (per-org trail) run on top of an already-loaded
/// surface, and list reloads carry the audit fields forward so an action or
/// a retry never wipes the trail.
class PlatformAdminCubit extends _PlatformAdminCubitBase
    with _PlatformAdminAudit {
  PlatformAdminCubit(super._gateway);

  /// Loads both metadata lists in parallel. A `denied` response from either
  /// list becomes [PlatformAdminDenied] — never empty success (AC-7). The
  /// audit trail (already-loaded section state) is carried forward.
  Future<void> load() async {
    if (state is PlatformAdminLoading) {
      return;
    }
    final PlatformAdminState current = state;
    // Carry the already-loaded trail across a reload, but NEVER carry an
    // in-flight `auditLoading` flag forward: the Audit section remounts
    // after this Loading window and re-triggers its own fetch, so a carried
    // `true` would strand it on a permanent spinner (reviewer finding,
    // audit T4). A fetch that lands on this Loading state is dropped by
    // design; the remounted section self-heals.
    final (
      List<AuditEntry> platformAudit,
      List<AuditEntry> orgAudit,
      String? selectedAuditOrgId,
      OrgFailureKind? auditError,
    ) = current is PlatformAdminLoaded
        ? (
            current.platformAudit,
            current.orgAudit,
            current.selectedAuditOrgId,
            current.auditError,
          )
        : (const <AuditEntry>[], const <AuditEntry>[], null, null);
    emit(const PlatformAdminLoading());
    final (
      OrgOutcome<List<OrganizationSummary>> orgs,
      OrgOutcome<List<OrgMember>> members,
    ) = await (
      _gateway.listOrganizations(),
      _gateway.listMembers(),
    ).wait;
    if (isClosed) {
      return;
    }
    final bool denied =
        orgs.failureOrNull?.kind == OrgFailureKind.denied ||
        members.failureOrNull?.kind == OrgFailureKind.denied;
    if (denied) {
      emit(const PlatformAdminDenied());
      return;
    }
    switch ((orgs, members)) {
      case (
        OrgSuccess<List<OrganizationSummary>>(
          value: final List<OrganizationSummary> organizationList,
        ),
        OrgSuccess<List<OrgMember>>(value: final List<OrgMember> memberList),
      ):
        emit(
          PlatformAdminLoaded(
            organizationList,
            memberList,
            platformAudit: platformAudit,
            orgAudit: orgAudit,
            selectedAuditOrgId: selectedAuditOrgId,
            auditLoading: false,
            auditError: auditError,
          ),
        );
      case (
        OrgFailed<List<OrganizationSummary>>(
          failure: final OrgFailure orgFailure,
        ),
        _,
      ):
        emit(PlatformAdminFailed(_appError(orgFailure), orgFailure.kind));
      case (
        _,
        OrgFailed<List<OrgMember>>(failure: final OrgFailure memberFailure),
      ):
        emit(PlatformAdminFailed(_appError(memberFailure), memberFailure.kind));
    }
  }

  /// Suspends a membership in ANY organization (platform boundary). Returns
  /// the typed failure kind on failure, or null on success (lists reload).
  Future<OrgFailureKind?> suspendMembership({
    required String organizationId,
    required String userId,
  }) => _runAction(
    userId: userId,
    call: () => _gateway.suspendMembership(
      organizationId: organizationId,
      userId: userId,
    ),
  );

  /// Reactivates a suspended membership in any organization.
  Future<OrgFailureKind?> reactivateMembership({
    required String organizationId,
    required String userId,
  }) => _runAction(
    userId: userId,
    call: () => _gateway.reactivateMembership(
      organizationId: organizationId,
      userId: userId,
    ),
  );

  /// Deletes a demo account (`delete_demo_account`; the RPC refuses the
  /// caller's own id — never self). Returns the typed failure kind on
  /// failure, or null on success (lists reload; the deleted row leaves).
  Future<OrgFailureKind?> deleteDemoAccount({required String userId}) =>
      _runAction(
        userId: userId,
        call: () => _gateway.deleteDemoAccount(userId: userId),
      );

  /// Runs an action: marks the member row in-flight, calls the seam, reloads
  /// both lists on success, and restores the previous lists on failure. The
  /// audit trail is carried across both emissions (never wiped by an action).
  Future<OrgFailureKind?> _runAction({
    required String userId,
    required Future<OrgOutcome<void>> Function() call,
  }) async {
    final PlatformAdminState current = state;
    if (current is! PlatformAdminLoaded) {
      return null;
    }
    emit(current.copyWith(pendingUserId: userId));
    final OrgOutcome<void> outcome = await call();
    if (isClosed) {
      return null;
    }
    switch (outcome) {
      case OrgSuccess<void>():
        await load();
        return null;
      case OrgFailed<void>(failure: final OrgFailure failure):
        emit(
          // pendingUserId deliberately cleared: the action finished
          // (failed), so the row spinner goes. Explicit full construction —
          // copyWith cannot clear it.
          PlatformAdminLoaded(
            current.organizations,
            current.members,
            platformAudit: current.platformAudit,
            orgAudit: current.orgAudit,
            selectedAuditOrgId: current.selectedAuditOrgId,
            auditLoading: current.auditLoading,
            auditError: current.auditError,
          ),
        );
        return failure.kind;
    }
  }

  AppError _appError(OrgFailure failure) => AppError(
    code: 'platformAdmin.${failure.kind.name}',
    userMessage: failure.message ?? 'Platform administration failed',
  );
}
