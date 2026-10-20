library;

/// Localized labels for synthetic demo copy (2026-09-24).
///
/// The fake gateways serve fixed English demo strings (matter titles,
/// attorney bios, thread titles, notification types/summaries, …). Those
/// strings are DATA, so they cross the seam untranslated (the data layer
/// never imports l10n); presentation maps the known demo values to
/// localized labels here, following the established `practiceAreaLabel` /
/// `documentTypeLabel` / `notificationCategoryLabel` pattern.
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
import '../l10n/app_localizations.dart';

/// Notification tile title for a demo `type` wire value.
String demoNotificationType(AppLocalizations l10n, String type) =>
    switch (type) {
      'invoice_status' => l10n.notifTypeInvoiceStatus,
      'matter_updated' => l10n.notifTypeMatterUpdated,
      'appointment_reminder' => l10n.notifTypeAppointmentReminder,
      'message_received' => l10n.notifTypeMessageReceived,
      'system_maintenance' => l10n.notifTypeSystemMaintenance,
      _ => type,
    };

/// Notification tile summary, keyed by the row's demo `type` (1:1 in the
/// fake corpus). [fallback] is the row's own summary, kept for unknown
/// server types.
String demoNotificationSummary(
  AppLocalizations l10n,
  String type,
  String fallback,
) => switch (type) {
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
String demoMatterTitle(AppLocalizations l10n, String title) => switch (title) {
  'Demo acquisition review' => l10n.demoMatterTitle1,
  'Commercial lease consultation' => l10n.demoMatterTitle2,
  'Procedural review matter' => l10n.demoMatterTitle3,
  'Family status consultation' => l10n.demoMatterTitle4,
  'Startup formation advisory' => l10n.demoMatterTitle5,
  _ => title,
};

/// Attorney bio line. Names are identities and stay raw.
String demoAttorneyBio(AppLocalizations l10n, String bio) => switch (bio) {
  'Corporate transactions and governance counsel.' => l10n.demoAttorneyBio1,
  'Civil litigation and contracts.' => l10n.demoAttorneyBio2,
  'Criminal defense and procedure.' => l10n.demoAttorneyBio3,
  'Family law and personal status matters.' => l10n.demoAttorneyBio4,
  'Startup formation and advisory work.' => l10n.demoAttorneyBio5,
  _ => bio,
};

/// Message-thread title.
String demoThreadTitle(AppLocalizations l10n, String title) => switch (title) {
  'Demo matter updates' => l10n.demoThreadTitle1,
  'Consultation follow-up — demo' => l10n.demoThreadTitle2,
  'Demo procedural notes' => l10n.demoThreadTitle3,
  'Family matter thread — demo' => l10n.demoThreadTitle4,
  'Startup advisory — demo' => l10n.demoThreadTitle5,
  _ => title,
};

/// Synthetic message body (`Demo message <n> — generic demo content…`).
/// User-composed bodies never match the pattern and pass through.
final RegExp _demoMessagePattern = RegExp(
  r'^Demo message (\d+) — generic demo content',
);

String demoMessageBody(AppLocalizations l10n, String body) {
  final RegExpMatch? match = _demoMessagePattern.firstMatch(body);
  if (match == null) {
    return body;
  }
  return l10n.demoMessageBody(int.parse(match.group(1)!));
}

/// Generic demo author names. Real display names pass through.
String demoAuthorName(AppLocalizations l10n, String name) => switch (name) {
  'Demo attorney' => l10n.demoAuthorAttorney,
  'Demo client' => l10n.demoAuthorClient,
  _ => name,
};

/// Document title.
String demoDocumentTitle(AppLocalizations l10n, String title) =>
    switch (title) {
      'Demo engagement letter' => l10n.demoDocumentTitle1,
      'Sample matter brief — demo' => l10n.demoDocumentTitle2,
      'Demo evidence index' => l10n.demoDocumentTitle3,
      'Correspondence log — demo' => l10n.demoDocumentTitle4,
      'Demo settlement draft' => l10n.demoDocumentTitle5,
      _ => title,
    };

/// Vault file name.
String demoFileName(AppLocalizations l10n, String name) => switch (name) {
  'Demo retainer scan' => l10n.demoFileName1,
  'Demo lease annex' => l10n.demoFileName2,
  'Demo evidence register' => l10n.demoFileName3,
  'Demo correspondence copy' => l10n.demoFileName4,
  'Demo formation checklist' => l10n.demoFileName5,
  _ => name,
};

/// Compliance-alert title.
String demoAlertTitle(AppLocalizations l10n, String title) => switch (title) {
  'Demo: review pending invitations' => l10n.demoAlertTitle1,
  'Demo: data-access review due' => l10n.demoAlertTitle2,
  'Demo: sample alert — high traffic' => l10n.demoAlertTitle3,
  'Demo: retention window expiring' => l10n.demoAlertTitle4,
  'Demo: review completed' => l10n.demoAlertTitle5,
  _ => title,
};

/// Task-board title.
String demoTaskTitle(AppLocalizations l10n, String title) => switch (title) {
  'Demo: draft response checklist' => l10n.demoTaskTitle1,
  'Demo: gather documents' => l10n.demoTaskTitle2,
  'Demo: review client notes' => l10n.demoTaskTitle3,
  'Demo: schedule follow-up' => l10n.demoTaskTitle4,
  'Demo: update matter timeline' => l10n.demoTaskTitle5,
  _ => title,
};

/// Approval reference line. The engagement-letter reference is shared with
/// the documents corpus and maps through the same key.
String demoApprovalReference(AppLocalizations l10n, String reference) =>
    switch (reference) {
      'Demo invite — review' => l10n.demoApprovalRefInviteReview,
      'Demo role change' => l10n.demoApprovalRefRoleChange,
      'Demo engagement letter' => l10n.demoDocumentTitle1,
      'Sample invite — expired' => l10n.demoApprovalRefInviteExpired,
      'Demo suspension review' => l10n.demoApprovalRefSuspension,
      _ => reference,
    };

/// Approval entity-type wire value.
String demoApprovalEntityType(AppLocalizations l10n, String entityType) =>
    switch (entityType) {
      'invitation' => l10n.demoApprovalEntityInvitation,
      'membership' => l10n.demoApprovalEntityMembership,
      'document' => l10n.demoApprovalEntityDocument,
      _ => entityType,
    };

/// Video-consultation topic. Participant names are identities and stay raw.
String demoVideoTopic(AppLocalizations l10n, String topic) => switch (topic) {
  'Contract review — kickoff' => l10n.demoVideoTopic1,
  'Incorporation walkthrough' => l10n.demoVideoTopic2,
  'Employment dispute — follow-up' => l10n.demoVideoTopic3,
  'Family law consultation' => l10n.demoVideoTopic4,
  _ => topic,
};

/// Research citation title: tries the document, matter, and thread corpora
/// (sources cite all three). Unknown titles pass through.
String demoCorpusTitle(AppLocalizations l10n, String title) {
  final String asDocument = demoDocumentTitle(l10n, title);
  if (asDocument != title) {
    return asDocument;
  }
  final String asMatter = demoMatterTitle(l10n, title);
  if (asMatter != title) {
    return asMatter;
  }
  return demoThreadTitle(l10n, title);
}

/// Research citation detail: the document-type / practice-area wire names
/// resolve through the existing enum labels; the related-matter marker has
/// its own key. Unknown details pass through.
String demoSourceDetail(AppLocalizations l10n, String detail) =>
    switch (detail) {
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
