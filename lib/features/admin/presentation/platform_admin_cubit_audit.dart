part of 'platform_admin_cubit.dart';

/// The section-local audit-trail group of [PlatformAdminCubit] — the
/// same method bodies moved verbatim; the class applies this mixin.
mixin _PlatformAdminAudit on _PlatformAdminCubitBase {
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
      // Deliberately re-defaults platformAudit/orgAudit/selectedAuditOrgId/
      // auditError: the incoming PLATFORM trail replaces any org-scoped
      // view, and a stale error must not outlive the fresh fetch. Explicit
      // full construction — copyWith cannot express the clears (M-2).
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
        // auditError is already null here (the in-flight emission above
        // cleared it), so carrying it equals the original default.
        emit(s.copyWith(platformAudit: entries, auditLoading: false));
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
        // Deliberately clears orgAudit/selectedAuditOrgId/auditError: a null
        // scope means back to the platform trail, and a stale org error must
        // not survive the scope switch. Explicit full construction —
        // copyWith cannot express the clears (M-2).
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
      // auditError deliberately dropped: a fresh fetch starts with a clean
      // error slate. Explicit full construction — copyWith cannot clear it.
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
        // auditError is already null here (the in-flight emission above
        // cleared it), so carrying it equals the original default.
        emit(
          s.copyWith(
            orgAudit: entries,
            selectedAuditOrgId: organizationId,
            auditLoading: false,
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
    emit(s.copyWith(auditError: failure.kind, auditLoading: false));
  }
}
