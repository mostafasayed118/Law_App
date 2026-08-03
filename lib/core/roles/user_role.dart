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
    required this.canViewAttorneyDiscovery,
    required this.canViewMatters,
    required this.canViewDocuments,
  });

  final bool canViewHome;
  final bool canViewSettings;

  /// Phase 5 (scope note D-B7): whether the home dashboard offers the
  /// consultation-booking entry. A navigation/visibility hint only, like the
  /// other flags — the demo booking flow makes no backend promise (D-B3).
  final bool canBookConsultation;

  /// Phase 6 (scope note D-A6): whether the home dashboard offers the
  /// attorney-discovery entry. A navigation/visibility hint only, like the
  /// other flags — discovery is read-only and the profile list is synthetic
  /// (D-A1/D-A2).
  final bool canViewAttorneyDiscovery;

  /// Phase 7 (scope note D-M6): whether the home dashboard offers the matter
  /// dashboard entry. A navigation/visibility hint only, like the other
  /// flags — matters are read-first and the list is synthetic (D-M1/D-M2).
  final bool canViewMatters;

  /// Phase 8 (scope note D-V5): whether the home dashboard offers the
  /// document-vault entry. A navigation/visibility hint only, like the
  /// other flags — documents are read-first, metadata-only, and the list
  /// is synthetic (D-V1/D-V2).
  final bool canViewDocuments;

  @override
  List<Object?> get props => <Object?>[
    canViewHome,
    canViewSettings,
    canBookConsultation,
    canViewAttorneyDiscovery,
    canViewMatters,
    canViewDocuments,
  ];
}

const Map<UserRole, RoleCapability> roleCapabilities =
    <UserRole, RoleCapability>{
      UserRole.client: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
      UserRole.attorney: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
      UserRole.partner: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
      UserRole.complianceOfficer: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
      UserRole.researchAnalyst: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
      UserRole.admin: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
      ),
    };
