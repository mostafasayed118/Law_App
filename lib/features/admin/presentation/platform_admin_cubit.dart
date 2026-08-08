import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/admin/platform_admin_gateway.dart';
import '../../../core/errors/app_error.dart';

/// Sealed presentation state for the platform-admin surface.
///
/// Loaded states own both metadata lists and the in-flight action indicator;
/// the distinct [PlatformAdminDenied] renders the non-owner server denial —
/// never an empty-success list (P3.5 AC-7).
sealed class PlatformAdminState extends Equatable {
  const PlatformAdminState();
}

/// No operation has been attempted yet.
final class PlatformAdminInitial extends PlatformAdminState {
  const PlatformAdminInitial();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Both metadata lists are loading.
final class PlatformAdminLoading extends PlatformAdminState {
  const PlatformAdminLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Both metadata lists loaded. [pendingUserId] marks the member row with an
/// in-flight action (row spinner); the previous lists stay visible while an
/// action runs.
///
/// The audit trail is section-local (the audit read runs separately from
/// [PlatformAdminCubit.load], triggered by the Audit section on mount —
/// mirroring the MatterDetailsScreen per-section pattern, D-AUD2): the
/// platform-wide trail ([platformAudit]) plus the org-scoped trail
/// ([orgAudit]) for the selected [selectedAuditOrgId]. A non-denial audit
/// read failure is carried as [auditError] so the already-loaded
/// orgs/members surface is never destroyed by a section failure.
final class PlatformAdminLoaded extends PlatformAdminState {
  const PlatformAdminLoaded(
    this.organizations,
    this.members, {
    this.pendingUserId,
    this.platformAudit = const <AuditEntry>[],
    this.orgAudit = const <AuditEntry>[],
    this.selectedAuditOrgId,
    this.auditLoading = false,
    this.auditError,
  });

  final List<OrganizationSummary> organizations;
  final List<OrgMember> members;
  final String? pendingUserId;

  /// The platform-wide trail (`read_platform_audit`), loaded section-locally
  /// when the Audit section mounts.
  final List<AuditEntry> platformAudit;

  /// The org-scoped trail (`read_org_audit`) for [selectedAuditOrgId].
  final List<AuditEntry> orgAudit;

  /// The org whose trail is shown; null renders the platform trail.
  final String? selectedAuditOrgId;

  /// True while an audit read is in flight (section-local spinner).
  final bool auditLoading;

  /// A non-denial audit read failure, surfaced inline in the section. A
  /// `denied` read instead flips the whole surface to [PlatformAdminDenied]
  /// (AC-7 — the caller is not the owner).
  final OrgFailureKind? auditError;

  @override
  List<Object?> get props => <Object?>[
    organizations,
    members,
    pendingUserId,
    platformAudit,
    orgAudit,
    selectedAuditOrgId,
    auditLoading,
    auditError,
  ];
}

/// The owner-only RPCs denied server-side (`permission denied`): the caller
/// is not the platform owner. Distinct from a failure and never rendered as
/// an empty success.
final class PlatformAdminDenied extends PlatformAdminState {
  const PlatformAdminDenied();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The metadata lists failed with a non-denial failure.
final class PlatformAdminFailed extends PlatformAdminState {
  const PlatformAdminFailed(this.error, this.kind);

  final AppError error;
  final OrgFailureKind kind;

  @override
  List<Object?> get props => <Object?>[error, kind];
}

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
class PlatformAdminCubit extends Cubit<PlatformAdminState> {
  PlatformAdminCubit(this._gateway) : super(const PlatformAdminInitial());

  final PlatformAdminGateway _gateway;

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

  /// Loads the platform-wide audit trail. Triggered section-locally by the
  /// Audit section on mount (not part of [load]). A `denied` read becomes
  /// [PlatformAdminDenied] (AC-7 — never an empty-success trail); a
  /// non-denial failure is carried as [PlatformAdminLoaded.auditError] so
  /// the loaded orgs/members surface stays visible.
  Future<void> loadAudit() async {
    final PlatformAdminState current = state;
    if (current is! PlatformAdminLoaded || current.auditLoading) {
      return;
    }
    emit(
      PlatformAdminLoaded(
        current.organizations,
        current.members,
        pendingUserId: current.pendingUserId,
        auditLoading: true,
      ),
    );
    final OrgOutcome<List<AuditEntry>> outcome = await _gateway
        .readPlatformAudit();
    if (isClosed) {
      return;
    }
    switch (outcome) {
      case OrgSuccess<List<AuditEntry>>(value: final List<AuditEntry> entries):
        final PlatformAdminState s = state;
        if (s is! PlatformAdminLoaded) {
          return;
        }
        emit(
          PlatformAdminLoaded(
            s.organizations,
            s.members,
            pendingUserId: s.pendingUserId,
            platformAudit: entries,
            orgAudit: s.orgAudit,
            selectedAuditOrgId: s.selectedAuditOrgId,
          ),
        );
      case OrgFailed<List<AuditEntry>>(failure: final OrgFailure failure):
        _auditFailure(failure);
    }
  }

  /// Selects the per-org audit scope. null clears the org trail (no fetch);
  /// a non-null org id fetches that org's trail (`read_org_audit`),
  /// section-locally. Same denied/failure routing as [loadAudit].
  Future<void> selectAuditOrg(String? organizationId) async {
    final PlatformAdminState current = state;
    if (current is! PlatformAdminLoaded || current.auditLoading) {
      return;
    }
    if (organizationId == null) {
      emit(
        PlatformAdminLoaded(
          current.organizations,
          current.members,
          pendingUserId: current.pendingUserId,
          platformAudit: current.platformAudit,
        ),
      );
      return;
    }
    emit(
      PlatformAdminLoaded(
        current.organizations,
        current.members,
        pendingUserId: current.pendingUserId,
        platformAudit: current.platformAudit,
        orgAudit: current.orgAudit,
        selectedAuditOrgId: organizationId,
        auditLoading: true,
      ),
    );
    final OrgOutcome<List<AuditEntry>> outcome = await _gateway.readOrgAudit(
      organizationId: organizationId,
    );
    if (isClosed) {
      return;
    }
    switch (outcome) {
      case OrgSuccess<List<AuditEntry>>(value: final List<AuditEntry> entries):
        final PlatformAdminState s = state;
        if (s is! PlatformAdminLoaded) {
          return;
        }
        emit(
          PlatformAdminLoaded(
            s.organizations,
            s.members,
            pendingUserId: s.pendingUserId,
            platformAudit: s.platformAudit,
            orgAudit: entries,
            selectedAuditOrgId: organizationId,
          ),
        );
      case OrgFailed<List<AuditEntry>>(failure: final OrgFailure failure):
        _auditFailure(failure);
    }
  }

  /// Routes an audit read failure: `denied` flips the whole surface to the
  /// distinct denied state (AC-7); anything else is carried as the inline
  /// section error so the loaded lists survive.
  void _auditFailure(OrgFailure failure) {
    if (failure.kind == OrgFailureKind.denied) {
      emit(const PlatformAdminDenied());
      return;
    }
    final PlatformAdminState s = state;
    if (s is! PlatformAdminLoaded) {
      return;
    }
    emit(
      PlatformAdminLoaded(
        s.organizations,
        s.members,
        pendingUserId: s.pendingUserId,
        platformAudit: s.platformAudit,
        orgAudit: s.orgAudit,
        selectedAuditOrgId: s.selectedAuditOrgId,
        auditError: failure.kind,
      ),
    );
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
    emit(
      PlatformAdminLoaded(
        current.organizations,
        current.members,
        pendingUserId: userId,
        platformAudit: current.platformAudit,
        orgAudit: current.orgAudit,
        selectedAuditOrgId: current.selectedAuditOrgId,
        auditLoading: current.auditLoading,
        auditError: current.auditError,
      ),
    );
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
