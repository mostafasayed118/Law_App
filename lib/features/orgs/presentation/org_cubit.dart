import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/roles/user_role.dart';

/// Sealed presentation state for the organization surface.
///
/// Roster states own the member list and the in-flight action indicator;
/// create states own the create-org flow. Invites and per-row actions are
/// driven from the roster (or create flow) and refresh the roster on success,
/// so the server stays the authority and the screen never mutates members.
sealed class OrgState extends Equatable {
  const OrgState();
}

/// No operation has been attempted yet.
final class OrgInitial extends OrgState {
  const OrgInitial();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A create-organization call is in flight.
final class OrgCreateLoading extends OrgState {
  const OrgCreateLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The organization was created; the caller is its initial partner.
final class OrgCreateSuccess extends OrgState {
  const OrgCreateSuccess(this.organization);

  final OrganizationSummary organization;

  @override
  List<Object?> get props => <Object?>[organization];
}

/// A create-organization call failed with a typed, safe failure.
final class OrgCreateFailed extends OrgState {
  const OrgCreateFailed(this.error, this.kind);

  final AppError error;
  final OrgFailureKind kind;

  @override
  List<Object?> get props => <Object?>[error, kind];
}

/// The member list is loading.
final class OrgRosterLoading extends OrgState {
  const OrgRosterLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The member list loaded. [pendingUserId] marks the member with an
/// in-flight action (spinner on that row); the previous list stays visible
/// while an action runs.
final class OrgRosterLoaded extends OrgState {
  const OrgRosterLoaded(this.members, {this.pendingUserId});

  final List<OrgMember> members;
  final String? pendingUserId;

  @override
  List<Object?> get props => <Object?>[members, pendingUserId];
}

/// The member list failed to load. [organizationId] lets the retry re-issue
/// the same load without the screen re-deriving it.
final class OrgRosterFailed extends OrgState {
  const OrgRosterFailed(this.error, this.kind, this.organizationId);

  final AppError error;
  final OrgFailureKind kind;
  final String organizationId;

  @override
  List<Object?> get props => <Object?>[error, kind, organizationId];
}

/// Owns the organization surface: create-org flow, member roster, and the
/// partner-only member actions, all against the [OrganizationGateway] seam.
///
/// The server is the authority (P3 spec §2): the cubit never fabricates
/// members or statuses — actions call the seam and refresh the roster on
/// success. Action methods return the typed [OrgFailureKind] on failure so
/// the screen can surface a localized message while the last good roster
/// stays on screen.
class OrgCubit extends Cubit<OrgState> {
  OrgCubit(this._gateway) : super(const OrgInitial());

  final OrganizationGateway _gateway;

  /// Creates an organization. Emits [OrgCreateLoading] then
  /// [OrgCreateSuccess] or [OrgCreateFailed].
  Future<void> createOrganization({required String name}) async {
    if (state is OrgCreateLoading) {
      return;
    }
    emit(const OrgCreateLoading());
    final OrgOutcome<OrganizationSummary> outcome = await _gateway
        .createOrganization(name: name);
    if (isClosed) {
      return;
    }
    switch (outcome) {
      case OrgSuccess<OrganizationSummary>(
        value: final OrganizationSummary summary,
      ):
        emit(OrgCreateSuccess(summary));
      case OrgFailed<OrganizationSummary>(failure: final OrgFailure failure):
        emit(OrgCreateFailed(_appError(failure), failure.kind));
    }
  }

  /// Loads the member roster for one organization. Emits
  /// [OrgRosterLoading] then [OrgRosterLoaded] or [OrgRosterFailed].
  Future<void> loadRoster({required String organizationId}) async {
    if (state is OrgRosterLoading) {
      return;
    }
    emit(const OrgRosterLoading());
    final OrgOutcome<List<OrgMember>> outcome = await _gateway.listMembers(
      organizationId: organizationId,
    );
    if (isClosed) {
      return;
    }
    switch (outcome) {
      case OrgSuccess<List<OrgMember>>(value: final List<OrgMember> members):
        emit(OrgRosterLoaded(members));
      case OrgFailed<List<OrgMember>>(failure: final OrgFailure failure):
        emit(OrgRosterFailed(_appError(failure), failure.kind, organizationId));
    }
  }

  /// Changes a member's role. Returns the typed failure kind on failure, or
  /// null on success (the roster is refreshed).
  Future<OrgFailureKind?> changeMemberRole({
    required String organizationId,
    required String userId,
    required UserRole role,
  }) => _runAction(
    organizationId: organizationId,
    userId: userId,
    call: () => _gateway.changeMemberRole(
      organizationId: organizationId,
      userId: userId,
      role: role,
    ),
  );

  /// Suspends a member. Returns the typed failure kind on failure, or null on
  /// success (the roster is refreshed).
  Future<OrgFailureKind?> suspendMember({
    required String organizationId,
    required String userId,
  }) => _runAction(
    organizationId: organizationId,
    userId: userId,
    call: () =>
        _gateway.suspendMember(organizationId: organizationId, userId: userId),
  );

  /// Reactivates a suspended member. Returns the typed failure kind on
  /// failure, or null on success (the roster is refreshed).
  Future<OrgFailureKind?> reactivateMember({
    required String organizationId,
    required String userId,
  }) => _runAction(
    organizationId: organizationId,
    userId: userId,
    call: () => _gateway.reactivateMember(
      organizationId: organizationId,
      userId: userId,
    ),
  );

  /// Removes a member. Returns the typed failure kind on failure, or null on
  /// success (the roster is refreshed).
  Future<OrgFailureKind?> removeMember({
    required String organizationId,
    required String userId,
  }) => _runAction(
    organizationId: organizationId,
    userId: userId,
    call: () =>
        _gateway.removeMember(organizationId: organizationId, userId: userId),
  );

  /// Rotates a PENDING invite's token (Phase 2 slice 2.1). Returns the fresh
  /// one-time token on success (the roster is refreshed), or the typed
  /// failure kind on failure. On failure the last good roster is restored.
  Future<OrgInviteActionResult> resendInvitation({
    required String organizationId,
    required String invitationId,
    required String email,
  }) async {
    final OrgState current = state;
    if (current is! OrgRosterLoaded) {
      return const OrgInviteActionResult.failure(null);
    }
    emit(OrgRosterLoaded(current.members, pendingUserId: email));
    final OrgOutcome<String> outcome = await _gateway.resendInvitation(
      invitationId: invitationId,
    );
    if (isClosed) {
      return const OrgInviteActionResult.failure(null);
    }
    switch (outcome) {
      case OrgSuccess<String>(value: final String token):
        await loadRoster(organizationId: organizationId);
        return OrgInviteActionResult.success(token);
      case OrgFailed<String>(failure: final OrgFailure failure):
        emit(OrgRosterLoaded(current.members));
        return OrgInviteActionResult.failure(failure.kind);
    }
  }

  /// Revokes a PENDING invite (Phase 2 slice 2.1). Returns the typed failure
  /// kind on failure, or null on success (the roster is refreshed so the
  /// revoked invited row leaves the pending list).
  Future<OrgFailureKind?> revokeInvitation({
    required String organizationId,
    required String invitationId,
    required String email,
  }) => _runAction(
    organizationId: organizationId,
    userId: email,
    call: () => _gateway.revokeInvitation(invitationId: invitationId),
  );

  /// Runs a member action: marks the row in-flight, calls the seam, refreshes
  /// the roster on success, and restores the previous roster on failure.
  Future<OrgFailureKind?> _runAction({
    required String organizationId,
    required String userId,
    required Future<OrgOutcome<void>> Function() call,
  }) async {
    final OrgState current = state;
    if (current is! OrgRosterLoaded) {
      return null;
    }
    emit(OrgRosterLoaded(current.members, pendingUserId: userId));
    final OrgOutcome<void> outcome = await call();
    if (isClosed) {
      return null;
    }
    switch (outcome) {
      case OrgSuccess<void>():
        await loadRoster(organizationId: organizationId);
        return null;
      case OrgFailed<void>(failure: final OrgFailure failure):
        emit(OrgRosterLoaded(current.members));
        return failure.kind;
    }
  }

  AppError _appError(OrgFailure failure) => AppError(
    code: 'org.${failure.kind.name}',
    userMessage: failure.message ?? 'Organization operation failed',
  );
}

/// Result of a token-returning invite action: the fresh one-time token on
/// success (shown once, out-of-band delivery), or the typed failure kind.
sealed class OrgInviteActionResult extends Equatable {
  const OrgInviteActionResult();

  const factory OrgInviteActionResult.success(String token) =
      OrgInviteActionSuccess;
  const factory OrgInviteActionResult.failure(OrgFailureKind? kind) =
      OrgInviteActionFailure;
}

final class OrgInviteActionSuccess extends OrgInviteActionResult {
  const OrgInviteActionSuccess(this.token);

  final String token;

  @override
  List<Object?> get props => <Object?>[token];
}

final class OrgInviteActionFailure extends OrgInviteActionResult {
  const OrgInviteActionFailure(this.kind);

  final OrgFailureKind? kind;

  @override
  List<Object?> get props => <Object?>[kind];
}
