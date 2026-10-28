part of 'fake_organization_gateway.dart';

enum _FakeInvitationStatus { pending, revoked, accepted }

/// A pending invitation mirror: the literal token is kept for demo
/// continuity (the real surface stores only the sha-256 hash — nothing
/// leaves the process, so the literal is safe here).
class _FakeInvitation {
  _FakeInvitation({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.status,
    required this.token,
  });

  final String id;
  final String organizationId;
  final String email;
  final UserRole role;
  _FakeInvitationStatus status;
  String token;
}
