import 'package:equatable/equatable.dart';

import '../roles/user_role.dart';

/// Lifecycle of an organization membership (contract §3.3).
enum MembershipStatus { invited, active, suspended, removed }

/// A user's membership in one organization with an organization-scoped role.
///
/// Contract §5: the session must not carry a single client-controlled `role`
/// as the authority. Roles live inside memberships with an explicit lifecycle
/// status; the server boundary remains the source of truth in production.
class OrganizationMembership extends Equatable {
  const OrganizationMembership({
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.status,
  });

  final String organizationId;

  /// The organization's display name, when resolvable.
  ///
  /// P3.2 name-resolution note (plan §6): the `organizations` SELECT is
  /// active-member-only, so the name resolves for **active** memberships but
  /// is null for suspended/removed ones (their own membership row is visible
  /// while the org row is not). Presentation tolerates the null name.
  final String? organizationName;
  final UserRole role;
  final MembershipStatus status;

  bool get isActive => status == MembershipStatus.active;

  @override
  List<Object?> get props => <Object?>[
    organizationId,
    organizationName,
    role,
    status,
  ];
}

/// Application session per contract §5: a stable `userId`, a display-safe
/// name, the user's organization memberships, and an expiry boundary.
///
/// There is deliberately **no single client-owned `role`** on the session.
/// Presentation may project a UX-only capability from [activeMembership];
/// that projection is a navigation hint, never an authorization grant.
class Session extends Equatable {
  const Session({
    required this.userId,
    required this.displayName,
    required this.memberships,
    required this.expiresAt,
  });

  /// Stable provider user id. An email address must never be used as a
  /// permanent authorization key (contract §3.1).
  final String userId;

  /// Display-safe identity for greetings and headers. Not copied into
  /// diagnostics by default (contract §3.1 privacy note).
  final String displayName;

  /// All memberships known to the client, each with its own lifecycle status.
  final List<OrganizationMembership> memberships;

  /// Expiry boundary; an expired session requires re-authentication.
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// The first membership with `active` status, or null when none is active.
  /// A suspended/removed membership must not project capabilities.
  OrganizationMembership? get activeMembership {
    for (final OrganizationMembership membership in memberships) {
      if (membership.isActive) {
        return membership;
      }
    }
    return null;
  }

  /// UX-only projection of the active membership's organization-scoped role.
  /// Navigation/capability hints read from here; it is never an
  /// authorization grant.
  UserRole? get primaryRole => activeMembership?.role;

  @override
  List<Object?> get props => <Object?>[
    userId,
    displayName,
    memberships,
    expiresAt,
  ];
}
