import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/organizations/organization_gateway.dart';

/// Sealed presentation state for the org-audit read surface
/// (`/organizations/audit`, partner org-audit slice 2026-08-09).
///
/// The server is the authority: the cubit renders exactly what
/// [`OrganizationGateway.readOrgAudit`] returns — redacted entries on
/// success, an honest empty list when the org has no events, and the
/// server's `permission denied` as the distinct [OrgAuditDenied] state
/// (AC-7: denied is never presented as empty success).
sealed class OrgAuditState extends Equatable {
  const OrgAuditState();
}

/// No load has been attempted yet.
final class OrgAuditInitial extends OrgAuditState {
  const OrgAuditInitial();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The org-audit read is in flight.
final class OrgAuditLoading extends OrgAuditState {
  const OrgAuditLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The redacted audit trail loaded. An empty list is an honest empty trail
/// (the screen renders the empty state — distinct from denial).
final class OrgAuditLoaded extends OrgAuditState {
  const OrgAuditLoaded(this.entries);

  final List<AuditEntry> entries;

  @override
  List<Object?> get props => <Object?>[entries];
}

/// The server denied the read (non-partner, cross-org, or
/// suspended/removed membership). Never rendered as empty success.
final class OrgAuditDenied extends OrgAuditState {
  const OrgAuditDenied();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The read failed (provider unavailable / unknown / provider drift).
/// [organizationId] lets the retry re-issue the same load.
final class OrgAuditFailed extends OrgAuditState {
  const OrgAuditFailed(this.error, this.kind, this.organizationId);

  final AppError error;
  final OrgFailureKind kind;
  final String organizationId;

  @override
  List<Object?> get props => <Object?>[error, kind, organizationId];
}

/// Owns the org-audit read against the [OrganizationGateway] seam.
class OrgAuditCubit extends Cubit<OrgAuditState> {
  OrgAuditCubit(this._gateway) : super(const OrgAuditInitial());

  final OrganizationGateway _gateway;

  /// Loads the active organization's redacted audit trail. Emits
  /// [OrgAuditLoading] then [OrgAuditLoaded] / [OrgAuditDenied] /
  /// [OrgAuditFailed]. Guards against duplicate submissions and emits
  /// nothing after disposal.
  Future<void> load({required String organizationId}) async {
    if (state is OrgAuditLoading) {
      return;
    }
    emit(const OrgAuditLoading());
    final OrgOutcome<List<AuditEntry>> outcome = await _gateway.readOrgAudit(
      organizationId: organizationId,
    );
    if (isClosed) {
      return;
    }
    switch (outcome) {
      case OrgSuccess<List<AuditEntry>>(value: final List<AuditEntry> entries):
        emit(OrgAuditLoaded(entries));
      case OrgFailed<List<AuditEntry>>(failure: final OrgFailure failure):
        emit(
          failure.kind == OrgFailureKind.denied
              ? const OrgAuditDenied()
              : OrgAuditFailed(
                  _appError(failure),
                  failure.kind,
                  organizationId,
                ),
        );
    }
  }

  /// Re-issues the failed load (from [OrgAuditFailed] only).
  Future<void> retry() async {
    final OrgAuditState current = state;
    if (current is! OrgAuditFailed) {
      return;
    }
    await load(organizationId: current.organizationId);
  }

  AppError _appError(OrgFailure failure) => AppError(
    code: 'org.audit.${failure.kind.name}',
    userMessage: failure.message ?? 'Audit trail load failed',
  );
}
