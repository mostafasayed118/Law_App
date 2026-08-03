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
    required this.canBookConsultation,
  });

  final bool canViewHome;
  final bool canViewSettings;

  /// Phase 5 (scope note D-B7): whether the home dashboard offers the
  /// consultation-booking entry. A navigation/visibility hint only, like the
  /// other flags — the demo booking flow makes no backend promise (D-B3).
  final bool canBookConsultation;

  @override
  List<Object?> get props => <Object?>[
    canViewHome,
    canViewSettings,
    canBookConsultation,
  ];
}

const Map<UserRole, RoleCapability> roleCapabilities =
    <UserRole, RoleCapability>{
      UserRole.client: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
      UserRole.attorney: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
      UserRole.partner: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
      UserRole.complianceOfficer: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
      UserRole.researchAnalyst: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
      UserRole.admin: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
      ),
    };
