part of 'platform_admin_cubit.dart';

/// (Readability split: the state hierarchy moved out of the cubit file
/// verbatim — same public names, same import path for consumers.)
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

  /// Copies this state with the given fields replaced (null = keep the
  /// current value — the standard copyWith convention).
  ///
  /// Transitions that deliberately CLEAR an optional field (a fresh fetch
  /// resetting the error slate, an action finishing removing the row
  /// spinner) stay as explicit full constructions at their emit sites so
  /// the drop is visible and reviewable — this convention cannot express
  /// them, and a silent keep would be a behavior change (M-2, audit
  /// 2026-09-21).
  PlatformAdminLoaded copyWith({
    List<OrganizationSummary>? organizations,
    List<OrgMember>? members,
    String? pendingUserId,
    List<AuditEntry>? platformAudit,
    List<AuditEntry>? orgAudit,
    String? selectedAuditOrgId,
    bool? auditLoading,
    OrgFailureKind? auditError,
  }) {
    return PlatformAdminLoaded(
      organizations ?? this.organizations,
      members ?? this.members,
      pendingUserId: pendingUserId ?? this.pendingUserId,
      platformAudit: platformAudit ?? this.platformAudit,
      orgAudit: orgAudit ?? this.orgAudit,
      selectedAuditOrgId: selectedAuditOrgId ?? this.selectedAuditOrgId,
      auditLoading: auditLoading ?? this.auditLoading,
      auditError: auditError ?? this.auditError,
    );
  }
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
