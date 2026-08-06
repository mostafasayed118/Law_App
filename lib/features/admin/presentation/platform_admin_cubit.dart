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
final class PlatformAdminLoaded extends PlatformAdminState {
  const PlatformAdminLoaded(
    this.organizations,
    this.members, {
    this.pendingUserId,
  });

  final List<OrganizationSummary> organizations;
  final List<OrgMember> members;
  final String? pendingUserId;

  @override
  List<Object?> get props => <Object?>[organizations, members, pendingUserId];
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
class PlatformAdminCubit extends Cubit<PlatformAdminState> {
  PlatformAdminCubit(this._gateway) : super(const PlatformAdminInitial());

  final PlatformAdminGateway _gateway;

  /// Loads both metadata lists in parallel. A `denied` response from either
  /// list becomes [PlatformAdminDenied] — never empty success (AC-7).
  Future<void> load() async {
    if (state is PlatformAdminLoading) {
      return;
    }
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
        emit(PlatformAdminLoaded(organizationList, memberList));
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
    organizationId: organizationId,
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
    organizationId: organizationId,
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
        organizationId: '',
        userId: userId,
        call: () => _gateway.deleteDemoAccount(userId: userId),
      );

  /// Runs an action: marks the member row in-flight, calls the seam, reloads
  /// both lists on success, and restores the previous lists on failure.
  Future<OrgFailureKind?> _runAction({
    required String organizationId,
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
        emit(PlatformAdminLoaded(current.organizations, current.members));
        return failure.kind;
    }
  }

  AppError _appError(OrgFailure failure) => AppError(
    code: 'platformAdmin.${failure.kind.name}',
    userMessage: failure.message ?? 'Platform administration failed',
  );
}
