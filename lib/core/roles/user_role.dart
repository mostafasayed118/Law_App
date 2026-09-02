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
    required this.canViewMessages,
    required this.canViewFiles,
    required this.canViewAudit,
    required this.canViewNotifications,
    required this.canViewAlerts,
    required this.canViewTasks,
    required this.canViewApprovals,
    required this.canUseAiResearch,
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

  /// Phase 9 (scope note D-MSG5): whether the home dashboard offers the
  /// messaging entry. A navigation/visibility hint only, like the other
  /// flags — messaging is read-only, thread-metadata-only, and the list
  /// is synthetic (D-MSG1/D-MSG2).
  final bool canViewMessages;

  /// Storage slice (D-STR7): whether the matter details surface offers the
  /// per-matter Files section. A navigation/visibility hint only, like the
  /// other flags — files are read-only, metadata-only, and the list is
  /// synthetic in env-less runs (D-STR3/D-STR9).
  final bool canViewFiles;

  /// Partner org-audit slice (2026-08-09 scope note): whether the org hub
  /// offers the "Audit trail" entry. A navigation/visibility hint only, like
  /// the other flags — `read_org_audit` is partner-capable server-side and
  /// the server denies everyone else; the client renders the typed denial
  /// (AC-7, never empty success). Granted to partner only.
  final bool canViewAudit;

  /// Notification-feed slice (D-N1): whether the home dashboard offers the
  /// org-scoped notification-feed entry. A navigation/visibility hint only,
  /// like the other flags — the feed is read-only metadata (D-N2/D-N3) and
  /// the server's `notifications_select_org` admits **any active member**
  /// (matrix §4 member SHIP — no role hierarchy in the feed, T1 Q3), so the
  /// flag is true for every authenticated role.
  final bool canViewNotifications;

  /// v1 queue (2026-08-09 scope drafts): whether the home dashboard offers
  /// the compliance-alerts entry. Read-only demo surface — nav hint only.
  final bool canViewAlerts;

  /// v1 queue (2026-08-09 scope drafts): whether the home dashboard offers
  /// the collaboration task-board entry. Read-only demo surface; nav hint
  /// only.
  final bool canViewTasks;

  /// v1 queue (2026-08-09 scope drafts): whether the home dashboard offers
  /// the pending-approvals entry. Read-only demo surface; nav hint only.
  final bool canViewApprovals;

  /// AI research slice (plan 2026-09-02, owner decision D-R1): whether the
  /// home dashboard offers the AI research-assistant entry. A
  /// navigation/visibility hint only, like the other flags — the surface is
  /// client-side synthetic research (no provider, no server boundary yet,
  /// D-1). Granted to the legal-facing roles: attorney, researchAnalyst,
  /// partner; denied to client, complianceOfficer, admin.
  final bool canUseAiResearch;

  @override
  List<Object?> get props => <Object?>[
    canViewHome,
    canViewSettings,
    canBookConsultation,
    canViewAttorneyDiscovery,
    canViewMatters,
    canViewDocuments,
    canViewMessages,
    canViewFiles,
    canViewAudit,
    canViewNotifications,
    canViewAlerts,
    canViewTasks,
    canViewApprovals,
    canUseAiResearch,
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
        canViewMessages: true,
        canViewFiles: true,
        canViewAudit: false,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: false,
      ),
      UserRole.attorney: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
        canViewFiles: true,
        canViewAudit: false,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: true,
      ),
      UserRole.partner: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
        canViewFiles: true,
        // Partner org-audit slice: the only role the server's
        // read_org_audit gate admits (navigation hint only).
        canViewAudit: true,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: true,
      ),
      UserRole.complianceOfficer: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
        canViewFiles: true,
        canViewAudit: false,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: false,
      ),
      UserRole.researchAnalyst: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
        canViewFiles: true,
        canViewAudit: false,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: true,
      ),
      UserRole.admin: RoleCapability(
        canViewHome: true,
        canViewSettings: true,
        canBookConsultation: true,
        canViewAttorneyDiscovery: true,
        canViewMatters: true,
        canViewDocuments: true,
        canViewMessages: true,
        canViewFiles: true,
        canViewAudit: false,
        canViewNotifications: true,
        canViewAlerts: true,
        canViewTasks: true,
        canViewApprovals: true,
        canUseAiResearch: false,
      ),
    };
