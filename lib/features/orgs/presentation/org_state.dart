part of 'org_cubit.dart';

/// (Readability split: the state hierarchy + invite-action result moved
/// out of the cubit file verbatim — same public names, same import path
/// for consumers.)
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

  /// Copies this state with the given fields replaced (null = keep the
  /// current value). Transitions that deliberately CLEAR [pendingUserId]
  /// (an action finished, spinner off) stay as explicit full constructions
  /// at their emit sites — this convention cannot express them (M-2, audit
  /// 2026-09-21).
  OrgRosterLoaded copyWith({List<OrgMember>? members, String? pendingUserId}) {
    return OrgRosterLoaded(
      members ?? this.members,
      pendingUserId: pendingUserId ?? this.pendingUserId,
    );
  }
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
