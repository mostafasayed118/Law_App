import 'package:equatable/equatable.dart';

import '../auth/session.dart';
import '../roles/user_role.dart';

export '../auth/session.dart' show MembershipStatus;

/// Server-side `org_role` names that can be assigned via the organization
/// RPC surface. The client `UserRole` enum is wider (compliance officer,
/// research analyst, admin) — those are UX roles with no server counterpart
/// and must never be sent to the boundary.
const Set<String> serverAssignableRoles = <String>{
  'client',
  'attorney',
  'partner',
};

/// Maps a server `org_role` name to the domain [UserRole], or null when the
/// name is not part of the assignable server surface.
UserRole? userRoleFromServerName(String? name) {
  return switch (name) {
    'client' => UserRole.client,
    'attorney' => UserRole.attorney,
    'partner' => UserRole.partner,
    _ => null,
  };
}

/// Maps a domain [UserRole] to its server `org_role` name.
///
/// Only [serverAssignableRoles] may cross the boundary; any other role is a
/// programmer error (the gateway validates before calling the seam).
String userRoleToServerName(UserRole role) {
  return switch (role) {
    UserRole.client => 'client',
    UserRole.attorney => 'attorney',
    UserRole.partner => 'partner',
    _ => throw ArgumentError.value(role, 'role', 'not assignable server-side'),
  };
}

/// Maps a server `membership_status` name to the domain [MembershipStatus],
/// or null when the name is unknown (provider drift — surfaces loudly, never
/// silently as a status the client does not understand).
MembershipStatus? membershipStatusFromServerName(String? name) {
  return switch (name) {
    'invited' => MembershipStatus.invited,
    'active' => MembershipStatus.active,
    'suspended' => MembershipStatus.suspended,
    'removed' => MembershipStatus.removed,
    _ => null,
  };
}

/// A member of an organization as returned by the metadata read surface:
/// identity (display name, locale) + membership metadata (role, status,
/// timestamps) only — never matter/document/message content (contract §5.3).
///
/// [invitationId] is set for invited rows when the read surface exposes it
/// (dev fake today; the member-facing roster RPC is Phase 3 R1). It stays
/// null for real members and for surfaces that cannot expose it — the
/// Resend/Revoke actions are disabled rather than guessing an id.
class OrgMember extends Equatable {
  const OrgMember({
    required this.organizationId,
    required this.userId,
    required this.displayName,
    this.locale,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.invitationId,
  });

  final String organizationId;
  final String userId;
  final String displayName;
  final String? locale;
  final UserRole role;
  final MembershipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Id of the underlying PENDING invitation for invited rows, when known.
  final String? invitationId;

  bool get isActive => status == MembershipStatus.active;

  @override
  List<Object?> get props => <Object?>[
    organizationId,
    userId,
    displayName,
    locale,
    role,
    status,
    createdAt,
    updatedAt,
    invitationId,
  ];
}

/// An organization owned/created through the organization surface.
class OrganizationSummary extends Equatable {
  const OrganizationSummary({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[id, name, createdAt];
}

/// The one-time invitation token minted by `invite_member`.
///
/// The token is displayed to the inviting partner for out-of-band delivery;
/// the server stores only its sha-256 hash. The email and organization are
/// echoed from the request for confirmation display.
class InviteResult extends Equatable {
  const InviteResult({
    required this.organizationId,
    required this.email,
    required this.token,
  });

  final String organizationId;
  final String email;
  final String token;

  @override
  List<Object?> get props => <Object?>[organizationId, email, token];
}

/// Typed reasons an organization operation can fail.
enum OrgFailureKind {
  /// The caller is not permitted to perform the operation (non-partner,
  /// cross-org target, or self-removal).
  denied,

  /// The invite target already has a membership in the organization.
  duplicateMember,

  /// The operation would leave the organization without an active partner.
  lastPartner,

  /// The requested role cannot be assigned (not on the server role surface).
  invalidRole,

  /// The organization name was empty/whitespace.
  invalidName,

  /// The invitation token is wrong, expired, or foreign (undifferentiated).
  invalidInvitation,

  /// The provider/configuration is unavailable.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed, safe organization failure crossing the domain boundary.
///
/// Only the [kind] and a non-sensitive [message] leave the seam. Invitation
/// tokens and PII must never be carried on this type.
class OrgFailure extends Equatable {
  const OrgFailure({required this.kind, this.message});

  final OrgFailureKind kind;
  final String? message;

  @override
  List<Object?> get props => <Object?>[kind, message];
}

/// Explicit success/failure boundary for organization domain operations.
sealed class OrgOutcome<T> {
  const OrgOutcome._();

  const factory OrgOutcome.success(T value) = OrgSuccess<T>;
  const factory OrgOutcome.failure(OrgFailure failure) = OrgFailed<T>;

  bool get isSuccess => this is OrgSuccess<T>;

  T? get valueOrNull => switch (this) {
    OrgSuccess<T>(value: final value) => value,
    OrgFailed<T>() => null,
  };

  OrgFailure? get failureOrNull => switch (this) {
    OrgSuccess<T>() => null,
    OrgFailed<T>(failure: final failure) => failure,
  };
}

final class OrgSuccess<T> extends OrgOutcome<T> {
  const OrgSuccess(this.value) : super._();

  final T value;
}

final class OrgFailed<T> extends OrgOutcome<T> {
  const OrgFailed(this.failure) : super._();

  final OrgFailure failure;
}
