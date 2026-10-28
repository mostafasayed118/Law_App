library;

/// Localized labels for synthetic demo copy (2026-09-24; posture-aware
/// 2026-10-26).
///
/// The fake gateways serve fixed English demo strings (matter titles,
/// attorney bios/headlines, thread titles, notification types/summaries,
/// approvals, compliance alerts, audit summaries, …). Those strings are
/// DATA, so they cross the seam untranslated (the data layer never imports
/// l10n); presentation maps the known demo values to localized labels here,
/// following the established `practiceAreaLabel` / `documentTypeLabel` /
/// `notificationCategoryLabel` pattern.
///
/// **Posture gate:** every method returns the server value unchanged unless
/// [localOnly] is true. A configured build therefore renders real backend
/// copy verbatim — it can never be mistaken for the demo corpus.
///
/// Two rules, applied everywhere:
/// - **Unknown values pass through raw.** A server-provided string the maps
///   below do not recognize is returned unchanged — real data must never
///   blank or mislabel (this also keeps user-typed content, e.g. a composed
///   message body or a created matter title, untouched).
/// - **Identities stay Latin.** Person names (`Layla Mansour`, `Omar
///   Farouk`), the demo display names (`Demo user`, `Demo client` as roster
///   identities), firm names, file paths, and reference codes (`LH-DEMO-*`)
///   are identities, not copy — only the generic role labels
///   (`demoAuthorAttorney` / `demoAuthorClient`) are localized.
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo/demo_corpus.dart';

/// Maps known synthetic demo values to localized copy when the app is on the
/// credential-free fakes; returns the server value verbatim otherwise.
class DemoLabels {
  const DemoLabels(this.l10n, {required this.localOnly});

  final AppLocalizations l10n;
  final bool localOnly;

  /// Notification tile title for a wire `type`. This is a wire-to-label map,
  /// not demo copy: known types are localized in every posture; unknown
  /// types pass through verbatim.
  String notificationType(String type) => _notificationType(type);

  String _notificationType(String type) => switch (type) {
    'invoice_status' => l10n.notifTypeInvoiceStatus,
    'matter_updated' => l10n.notifTypeMatterUpdated,
    'appointment_reminder' => l10n.notifTypeAppointmentReminder,
    'message_received' => l10n.notifTypeMessageReceived,
    'system_maintenance' => l10n.notifTypeSystemMaintenance,
    _ => type,
  };

  /// Notification tile summary. [fallback] is the row's own summary; a
  /// configured row (or an unknown demo type) keeps it verbatim. The demo
  /// corpus keys its summary by the row's `type` (1:1 in the fake).
  String notificationSummary(String type, String fallback) =>
      localOnly ? _notificationSummary(type, fallback) : fallback;

  String _notificationSummary(String type, String fallback) => switch (type) {
    'invoice_status' => l10n.notifSummaryInvoiceStatus,
    'matter_updated' => l10n.notifSummaryMatterUpdated,
    'appointment_reminder' => l10n.notifSummaryAppointmentReminder,
    'message_received' => l10n.notifSummaryMessageReceived,
    'system_maintenance' => l10n.notifSummarySystemMaintenance,
    _ => fallback,
  };

  /// Matter title + every `matterRef` derived from one (documents, messages,
  /// files, invoices, tasks all reference the five synthetic matter titles,
  /// D-W2). Unknown titles pass through (user-created matters).
  String matterTitle(String title) => localOnly ? _matterTitle(title) : title;

  String _matterTitle(String title) => switch (title) {
    DemoCorpus.matterTitleAcquisition => l10n.demoMatterTitle1,
    DemoCorpus.matterTitleLease => l10n.demoMatterTitle2,
    DemoCorpus.matterTitleProcedural => l10n.demoMatterTitle3,
    DemoCorpus.matterTitleFamily => l10n.demoMatterTitle4,
    DemoCorpus.matterTitleStartup => l10n.demoMatterTitle5,
    _ => title,
  };

  /// Attorney bio line. Names are identities and stay raw.
  String attorneyBio(String bio) => localOnly ? _attorneyBio(bio) : bio;

  String _attorneyBio(String bio) => switch (bio) {
    'Corporate transactions and governance counsel.' => l10n.demoAttorneyBio1,
    'Civil litigation and contracts.' => l10n.demoAttorneyBio2,
    'Criminal defense and procedure.' => l10n.demoAttorneyBio3,
    'Family law and personal status matters.' => l10n.demoAttorneyBio4,
    'Startup formation and advisory work.' => l10n.demoAttorneyBio5,
    _ => bio,
  };

  /// Discovery directory headline (the attorney's professional tagline).
  String attorneyHeadline(String headline) =>
      localOnly ? _attorneyHeadline(headline) : headline;

  String _attorneyHeadline(String headline) => switch (headline) {
    'Corporate and governance counsel' => l10n.demoAttorneyHeadlineCorporate,
    'Civil litigation and contracts' => l10n.demoAttorneyHeadlineCivil,
    'Criminal defense and procedure' => l10n.demoAttorneyHeadlineCriminal,
    'Family law and personal status' => l10n.demoAttorneyHeadlineFamily,
    'Startup formation and advisory' => l10n.demoAttorneyHeadlineStartup,
    _ => headline,
  };

  /// Message-thread title.
  String threadTitle(String title) => localOnly ? _threadTitle(title) : title;

  String _threadTitle(String title) => switch (title) {
    'Demo matter updates' => l10n.demoThreadTitle1,
    'Consultation follow-up — demo' => l10n.demoThreadTitle2,
    'Demo procedural notes' => l10n.demoThreadTitle3,
    'Family matter thread — demo' => l10n.demoThreadTitle4,
    'Startup advisory — demo' => l10n.demoThreadTitle5,
    _ => title,
  };

  /// Synthetic message body (`Demo message <n> — generic demo content…`).
  /// User-composed bodies never match the pattern and pass through.
  String messageBody(String body) => localOnly ? _messageBody(body) : body;

  String _messageBody(String body) {
    final RegExpMatch? match = _demoMessagePattern.firstMatch(body);
    if (match == null) {
      return body;
    }
    return l10n.demoMessageBody(int.parse(match.group(1)!));
  }

  /// Generic demo author names. Real display names pass through.
  String authorName(String name) => localOnly ? _authorName(name) : name;

  String _authorName(String name) => switch (name) {
    'Demo attorney' => l10n.demoAuthorAttorney,
    'Demo client' => l10n.demoAuthorClient,
    _ => name,
  };

  /// Document title.
  String documentTitle(String title) =>
      localOnly ? _documentTitle(title) : title;

  String _documentTitle(String title) => switch (title) {
    'Demo engagement letter' => l10n.demoDocumentTitle1,
    'Sample matter brief — demo' => l10n.demoDocumentTitle2,
    'Demo evidence index' => l10n.demoDocumentTitle3,
    'Correspondence log — demo' => l10n.demoDocumentTitle4,
    'Demo settlement draft' => l10n.demoDocumentTitle5,
    _ => title,
  };

  /// Vault file name.
  String fileName(String name) => localOnly ? _fileName(name) : name;

  String _fileName(String name) => switch (name) {
    'Demo retainer scan' => l10n.demoFileName1,
    'Demo lease annex' => l10n.demoFileName2,
    'Demo evidence register' => l10n.demoFileName3,
    'Demo correspondence copy' => l10n.demoFileName4,
    'Demo formation checklist' => l10n.demoFileName5,
    _ => name,
  };

  /// Compliance-alert title.
  String alertTitle(String title) => localOnly ? _alertTitle(title) : title;

  String _alertTitle(String title) => switch (title) {
    'Demo: review pending invitations' => l10n.demoAlertTitle1,
    'Demo: data-access review due' => l10n.demoAlertTitle2,
    'Demo: sample alert — high traffic' => l10n.demoAlertTitle3,
    'Demo: retention window expiring' => l10n.demoAlertTitle4,
    'Demo: review completed' => l10n.demoAlertTitle5,
    _ => title,
  };

  /// Compliance-alert description.
  String alertDescription(String description) =>
      localOnly ? _alertDescription(description) : description;

  String _alertDescription(String description) => switch (description) {
    'Synthetic demo alert — no real compliance event is shown.' =>
      l10n.demoAlertDescriptionReview,
    _ => description,
  };

  /// Approval-request title.
  String approvalTitle(String title) =>
      localOnly ? _approvalTitle(title) : title;

  String _approvalTitle(String title) => switch (title) {
    'Demo conflict check — new intake' => l10n.demoApprovalTitleConflictNew,
    'Demo engagement waiver' => l10n.demoApprovalTitleEngagementWaiver,
    'Demo court filing approval' => l10n.demoApprovalTitleCourtFiling,
    'Demo expense approval' => l10n.demoApprovalTitleExpense,
    'Demo conflict check — opposing counsel' =>
      l10n.demoApprovalTitleConflictOpposing,
    _ => title,
  };

  /// Approval-request description.
  String approvalDescription(String description) =>
      localOnly ? _approvalDescription(description) : description;

  String _approvalDescription(String description) => switch (description) {
    'Synthetic demo request — no real client or case data.' =>
      l10n.demoApprovalDescriptionWaiver,
    _ => description,
  };

  /// Approval decision note (the deciding partner's recorded remark).
  String approvalDecisionNote(String note) =>
      localOnly ? _approvalDecisionNote(note) : note;

  String _approvalDecisionNote(String note) => switch (note) {
    'Demo decision — approved.' => l10n.demoApprovalDecisionApproved,
    'Demo decision — rejected.' => l10n.demoApprovalDecisionRejected,
    _ => note,
  };

  /// Task-board title.
  String taskTitle(String title) => localOnly ? _taskTitle(title) : title;

  String _taskTitle(String title) => switch (title) {
    'Demo: draft response checklist' => l10n.demoTaskTitle1,
    'Demo: gather documents' => l10n.demoTaskTitle2,
    'Demo: review client notes' => l10n.demoTaskTitle3,
    'Demo: schedule follow-up' => l10n.demoTaskTitle4,
    'Demo: update matter timeline' => l10n.demoTaskTitle5,
    _ => title,
  };

  /// Research citation title: tries the document, matter, and thread corpora
  /// (sources cite all three). Unknown titles pass through.
  String corpusTitle(String title) => localOnly ? _corpusTitle(title) : title;

  String _corpusTitle(String title) {
    final String asDocument = _documentTitle(title);
    if (asDocument != title) {
      return asDocument;
    }
    final String asMatter = _matterTitle(title);
    if (asMatter != title) {
      return asMatter;
    }
    return _threadTitle(title);
  }

  /// Research citation detail: the document-type / practice-area wire names
  /// resolve through the existing enum labels; the related-matter marker has
  /// its own key. Unknown details pass through.
  String sourceDetail(String detail) =>
      localOnly ? _sourceDetail(detail) : detail;

  String _sourceDetail(String detail) => switch (detail) {
    'related demo matter' => l10n.researchRelatedMatter,
    'contract' => l10n.documentTypeContract,
    'brief' => l10n.documentTypeBrief,
    'evidence' => l10n.documentTypeEvidence,
    'correspondence' => l10n.documentTypeCorrespondence,
    'corporate' => l10n.areaCorporate,
    'civil' => l10n.areaCivil,
    'criminal' => l10n.areaCriminal,
    'family' => l10n.areaFamily,
    _ => detail,
  };

  /// Audit-trail redacted summary (server vocabulary; identities untouched).
  String auditSummary(String summary) =>
      localOnly ? _auditSummary(summary) : summary;

  String _auditSummary(String summary) => switch (summary) {
    'Organization created (metadata only)' => l10n.demoAuditOrganizationCreated,
    'Member invited (metadata only)' => l10n.demoAuditMemberInvited,
    'Member role changed (metadata only)' => l10n.demoAuditMemberRoleChanged,
    'Membership suspended (metadata only)' => l10n.demoAuditMembershipSuspended,
    'Demo account deleted (metadata only)' => l10n.demoAuditDemoAccountDeleted,
    'role change' => l10n.demoAuditRoleChange,
    'invitation sent' => l10n.demoAuditInvitationSent,
    'suspension denied' => l10n.demoAuditSuspensionDenied,
    _ => summary,
  };
}

final RegExp _demoMessagePattern = RegExp(
  r'^Demo message (\d+) — generic demo content',
);
