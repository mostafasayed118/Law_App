import 'package:equatable/equatable.dart';

enum UserRole {
  client,
  attorney,
  partner,
  complianceOfficer,
  researchAnalyst,
  admin,
}

/// Capabilities in bootstrap are navigation/visibility hints only.
/// They are NOT authorization. Consequential access must be enforced by the
/// future server/data boundary and tested there before real data is added.
class RoleCapability extends Equatable {
  const RoleCapability({
    required this.canViewHome,
    required this.canViewSettings,
  });

  final bool canViewHome;
  final bool canViewSettings;

  @override
  List<Object?> get props => <Object?>[canViewHome, canViewSettings];
}

const Map<UserRole, RoleCapability>
roleCapabilities = <UserRole, RoleCapability>{
  UserRole.client: RoleCapability(canViewHome: true, canViewSettings: true),
  UserRole.attorney: RoleCapability(canViewHome: true, canViewSettings: true),
  UserRole.partner: RoleCapability(canViewHome: true, canViewSettings: true),
  UserRole.complianceOfficer: RoleCapability(
    canViewHome: true,
    canViewSettings: true,
  ),
  UserRole.researchAnalyst: RoleCapability(
    canViewHome: true,
    canViewSettings: true,
  ),
  UserRole.admin: RoleCapability(canViewHome: true, canViewSettings: true),
};
