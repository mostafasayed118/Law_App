import 'package:equatable/equatable.dart';

enum UserRole {
  client,
  attorney,
  partner,
  complianceOfficer,
  researchAnalyst,
  admin,
}

/// The single capability tokens behind [RoleCapability].
///
/// Adding a capability is now a two-line change: one enum value here plus
/// one optional constructor parameter with its default below — the
/// `roleCapabilities` map only mentions roles that differ from the default.
/// Capability reads go through the `canX` getters.
enum Capability {
  viewHome,
  viewSettings,
  bookConsultation,
  viewAttorneyDiscovery,
  viewMatters,
  viewDocuments,
  viewMessages,
  viewFiles,
  viewAudit,
  viewNotifications,
  viewAlerts,
  viewTasks,
  viewApprovals,
  useAiResearch,
}

/// Capabilities in bootstrap are navigation/visibility hints only.
/// They are NOT authorization. Consequential access must be enforced by the
/// future server/data boundary and tested there before real data is added.
class RoleCapability extends Equatable {
  const RoleCapability({
    this.canViewHome = true,
    this.canViewSettings = true,
    this.canBookConsultation = true,
    this.canViewAttorneyDiscovery = true,
    this.canViewMatters = true,
    this.canViewDocuments = true,
    this.canViewMessages = true,
    this.canViewFiles = true,
    this.canViewAudit = false,
    this.canViewNotifications = true,
    this.canViewAlerts = true,
    this.canViewTasks = true,
    this.canViewApprovals = true,
    this.canUseAiResearch = false,
  });

  /// Builds the capability set from a [Set] of granted [Capability]s.
  /// Exact decode: only members of [granted] are true. Round-trips with
  /// [asSet] — `RoleCapability.fromSet(cap.asSet) == cap` for any [cap].
  factory RoleCapability.fromSet(Set<Capability> granted) {
    return RoleCapability(
      canViewHome: granted.contains(Capability.viewHome),
      canViewSettings: granted.contains(Capability.viewSettings),
      canBookConsultation: granted.contains(Capability.bookConsultation),
      canViewAttorneyDiscovery: granted.contains(
        Capability.viewAttorneyDiscovery,
      ),
      canViewMatters: granted.contains(Capability.viewMatters),
      canViewDocuments: granted.contains(Capability.viewDocuments),
      canViewMessages: granted.contains(Capability.viewMessages),
      canViewFiles: granted.contains(Capability.viewFiles),
      canViewAudit: granted.contains(Capability.viewAudit),
      canViewNotifications: granted.contains(Capability.viewNotifications),
      canViewAlerts: granted.contains(Capability.viewAlerts),
      canViewTasks: granted.contains(Capability.viewTasks),
      canViewApprovals: granted.contains(Capability.viewApprovals),
      canUseAiResearch: granted.contains(Capability.useAiResearch),
    );
  }

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

  /// The granted capabilities as a set. Round-trips:
  /// `RoleCapability.fromSet(cap.asSet) == cap`.
  Set<Capability> get asSet => <Capability>{
    if (canViewHome) Capability.viewHome,
    if (canViewSettings) Capability.viewSettings,
    if (canBookConsultation) Capability.bookConsultation,
    if (canViewAttorneyDiscovery) Capability.viewAttorneyDiscovery,
    if (canViewMatters) Capability.viewMatters,
    if (canViewDocuments) Capability.viewDocuments,
    if (canViewMessages) Capability.viewMessages,
    if (canViewFiles) Capability.viewFiles,
    if (canViewAudit) Capability.viewAudit,
    if (canViewNotifications) Capability.viewNotifications,
    if (canViewAlerts) Capability.viewAlerts,
    if (canViewTasks) Capability.viewTasks,
    if (canViewApprovals) Capability.viewApprovals,
    if (canUseAiResearch) Capability.useAiResearch,
  };

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

/// The role → navigation-hint matrix. Only deviations from the
/// [RoleCapability] defaults are spelled out: twelve flags are true for
/// every role, so each entry names at most the two varying flags —
/// [RoleCapability.canViewAudit] (partner only, the server's
/// `read_org_audit` gate is the authorization) and
/// [RoleCapability.canUseAiResearch] (legal-facing roles attorney /
/// researchAnalyst / partner, owner decision D-R1).
const Map<UserRole, RoleCapability>
roleCapabilities = <UserRole, RoleCapability>{
  UserRole.client: RoleCapability(),
  UserRole.attorney: RoleCapability(canUseAiResearch: true),
  // Partner org-audit slice: the only role the server's
  // read_org_audit gate admits (navigation hint only).
  UserRole.partner: RoleCapability(canViewAudit: true, canUseAiResearch: true),
  UserRole.complianceOfficer: RoleCapability(),
  UserRole.researchAnalyst: RoleCapability(canUseAiResearch: true),
  UserRole.admin: RoleCapability(),
};

/// Resolves the navigation hints for [role] from [capabilitiesForRole],
/// failing closed to least privilege (every entry hidden) when the map has
/// no entry for the role. Capabilities are UX-only navigation hints — the
/// server/data boundary is the authorization — so an unknown role must hide
/// surfaces, never throw a `_CastError` from a `!` unwrap. The router's
/// `capabilitiesForRole` parameter is an explicit test seam for restricted
/// roles, where partial maps are the normal case.
RoleCapability capabilityForRole(
  Map<UserRole, RoleCapability> capabilitiesForRole,
  UserRole role,
) {
  return capabilitiesForRole[role] ??
      RoleCapability.fromSet(const <Capability>{});
}
