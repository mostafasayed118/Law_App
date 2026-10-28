import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';

/// Pins the demo-copy localization contract (2026-09-24; posture-aware
/// 2026-10-26):
/// every known fake-gateway string maps to a localized label per locale,
/// unknown (server/user) strings pass through raw, identities are never
/// rewritten, and a configured posture returns server values verbatim.
void main() {
  late AppLocalizations en;
  late AppLocalizations ar;
  late DemoLabels localEn;
  late DemoLabels localAr;
  late DemoLabels configuredEn;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    localEn = DemoLabels(en, localOnly: true);
    localAr = DemoLabels(ar, localOnly: true);
    configuredEn = DemoLabels(en, localOnly: false);
  });

  group('posture gate', () {
    test('configured labels return every server value verbatim', () {
      // The notification wire type is a label map, not demo copy: it stays
      // localized in configured builds (only the summary is mode-gated).
      expect(
        configuredEn.notificationType('invoice_status'),
        en.notifTypeInvoiceStatus,
      );
      expect(configuredEn.notificationType('future_type'), 'future_type');
      expect(
        configuredEn.notificationSummary(
          'invoice_status',
          'Server invoice paid',
        ),
        'Server invoice paid',
      );
      expect(
        configuredEn.matterTitle('Demo acquisition review'),
        'Demo acquisition review',
      );
      expect(
        configuredEn.attorneyBio(
          'Corporate transactions and governance counsel.',
        ),
        'Corporate transactions and governance counsel.',
      );
      expect(
        configuredEn.attorneyHeadline('Corporate and governance counsel'),
        'Corporate and governance counsel',
      );
      expect(
        configuredEn.threadTitle('Demo matter updates'),
        'Demo matter updates',
      );
      expect(
        configuredEn.messageBody(
          'Demo message 3 — generic demo content, no real client or legal data.',
        ),
        'Demo message 3 — generic demo content, no real client or legal data.',
      );
      expect(configuredEn.authorName('Demo attorney'), 'Demo attorney');
      expect(
        configuredEn.documentTitle('Demo engagement letter'),
        'Demo engagement letter',
      );
      expect(configuredEn.fileName('Demo retainer scan'), 'Demo retainer scan');
      expect(
        configuredEn.alertTitle('Demo: review pending invitations'),
        'Demo: review pending invitations',
      );
      expect(
        configuredEn.alertDescription(
          'Synthetic demo alert — no real compliance event is shown.',
        ),
        'Synthetic demo alert — no real compliance event is shown.',
      );
      expect(
        configuredEn.approvalTitle('Demo engagement waiver'),
        'Demo engagement waiver',
      );
      expect(
        configuredEn.approvalDescription(
          'Synthetic demo request — no real client or case data.',
        ),
        'Synthetic demo request — no real client or case data.',
      );
      expect(
        configuredEn.approvalDecisionNote('Demo decision — approved.'),
        'Demo decision — approved.',
      );
      expect(
        configuredEn.taskTitle('Demo: gather documents'),
        'Demo: gather documents',
      );
      expect(
        configuredEn.corpusTitle('Demo engagement letter'),
        'Demo engagement letter',
      );
      expect(
        configuredEn.sourceDetail('related demo matter'),
        'related demo matter',
      );
      expect(
        configuredEn.auditSummary('Organization created (metadata only)'),
        'Organization created (metadata only)',
      );
    });

    test('configured labels skip a matching demo key', () {
      expect(
        DemoLabels(
          ar,
          localOnly: false,
        ).notificationSummary('invoice_status', 'Server invoice paid'),
        'Server invoice paid',
      );
      expect(
        DemoLabels(ar, localOnly: false).matterTitle('Demo acquisition review'),
        'Demo acquisition review',
      );
      expect(
        DemoLabels(ar, localOnly: false).auditSummary('role change'),
        'role change',
      );
    });
  });

  group('notification labels (P1a)', () {
    test('known types map per locale', () {
      expect(localEn.notificationType('invoice_status'), 'Invoice issued');
      expect(
        localAr.notificationType('invoice_status'),
        isNot('Invoice issued'),
      );
      expect(
        localEn.notificationSummary('invoice_status', 'fallback'),
        'Demo notification — invoice issued',
      );
    });

    test('unknown server types pass through', () {
      expect(localEn.notificationType('future_type'), 'future_type');
      expect(
        localEn.notificationSummary('future_type', 'raw summary'),
        'raw summary',
      );
    });
  });

  group('matter titles cover every matterRef', () {
    test('all five synthetic titles map', () {
      expect(
        localEn.matterTitle('Demo acquisition review'),
        en.demoMatterTitle1,
      );
      expect(
        localAr.matterTitle('Demo acquisition review'),
        isNot('Demo acquisition review'),
      );
      expect(
        localEn.matterTitle('Startup formation advisory'),
        en.demoMatterTitle5,
      );
    });

    test('user-created titles pass through', () {
      expect(localEn.matterTitle('My real case'), 'My real case');
    });
  });

  group('thread titles, bodies, authors', () {
    test('known thread titles map', () {
      expect(localEn.threadTitle('Demo matter updates'), en.demoThreadTitle1);
      expect(
        localAr.threadTitle('Demo matter updates'),
        isNot('Demo matter updates'),
      );
    });

    test('synthetic bodies map with the message number', () {
      expect(
        localEn.messageBody(
          'Demo message 3 — generic demo content, no real client or legal data.',
        ),
        en.demoMessageBody(3),
      );
    });

    test('user-composed bodies pass through', () {
      expect(localEn.messageBody('Hello counselor'), 'Hello counselor');
    });

    test('generic authors map, real names pass through', () {
      expect(localEn.authorName('Demo attorney'), en.demoAuthorAttorney);
      expect(localEn.authorName('Demo client'), en.demoAuthorClient);
      expect(localEn.authorName('Layla Mansour'), 'Layla Mansour');
    });
  });

  group('documents, files, alerts, tasks, approvals, video', () {
    test('all corpora map with raw fallback', () {
      expect(
        localEn.documentTitle('Demo engagement letter'),
        en.demoDocumentTitle1,
      );
      expect(localEn.documentTitle('Unknown doc'), 'Unknown doc');
      expect(localEn.fileName('Demo retainer scan'), en.demoFileName1);
      expect(localEn.fileName('contract.pdf'), 'contract.pdf');
      expect(
        localEn.alertTitle('Demo: review pending invitations'),
        en.demoAlertTitle1,
      );
      expect(localEn.taskTitle('Demo: gather documents'), en.demoTaskTitle2);
    });
  });

  group('approvals cluster (Task 26)', () {
    test('the eight rendered demo values map and keep identities', () {
      final List<(String, String Function(AppLocalizations))> values =
          <(String, String Function(AppLocalizations))>[
            (
              'Demo conflict check — new intake',
              (AppLocalizations l10n) => l10n.demoApprovalTitleConflictNew,
            ),
            (
              'Demo engagement waiver',
              (AppLocalizations l10n) => l10n.demoApprovalTitleEngagementWaiver,
            ),
            (
              'Demo court filing approval',
              (AppLocalizations l10n) => l10n.demoApprovalTitleCourtFiling,
            ),
            (
              'Demo expense approval',
              (AppLocalizations l10n) => l10n.demoApprovalTitleExpense,
            ),
            (
              'Demo conflict check — opposing counsel',
              (AppLocalizations l10n) => l10n.demoApprovalTitleConflictOpposing,
            ),
          ];
      for (final (String raw, String Function(AppLocalizations) label)
          in values) {
        expect(localEn.approvalTitle(raw), label(en));
        expect(localAr.approvalTitle(raw), label(ar));
        expect(localAr.approvalTitle(raw), isNot(raw));
      }
      expect(
        localEn.approvalDescription(
          'Synthetic demo request — no real client or case data.',
        ),
        en.demoApprovalDescriptionWaiver,
      );
      expect(
        localEn.approvalDecisionNote('Demo decision — approved.'),
        en.demoApprovalDecisionApproved,
      );
      expect(
        localEn.approvalDecisionNote('Demo decision — rejected.'),
        en.demoApprovalDecisionRejected,
      );
      // Identities do not translate: an unknown (server/user) title passes
      // through even in local mode.
      expect(
        localAr.approvalTitle('Layla Mansour request'),
        'Layla Mansour request',
      );
    });
  });

  group('compliance cluster (Task 26)', () {
    test('the five titles reuse the alert keys; the description is gated', () {
      for (final String title in <String>[
        'Demo: review pending invitations',
        'Demo: data-access review due',
        'Demo: sample alert — high traffic',
        'Demo: retention window expiring',
        'Demo: review completed',
      ]) {
        expect(localAr.alertTitle(title), isNot(title));
      }
      expect(
        localEn.alertDescription(
          'Synthetic demo alert — no real compliance event is shown.',
        ),
        en.demoAlertDescriptionReview,
      );
      expect(
        localAr.alertDescription(
          'Synthetic demo alert — no real compliance event is shown.',
        ),
        ar.demoAlertDescriptionReview,
      );
    });
  });

  group('discovery headline cluster (Task 26)', () {
    test('the five synthetic headlines map', () {
      final List<(String, String Function(AppLocalizations))> values =
          <(String, String Function(AppLocalizations))>[
            (
              'Corporate and governance counsel',
              (AppLocalizations l10n) => l10n.demoAttorneyHeadlineCorporate,
            ),
            (
              'Civil litigation and contracts',
              (AppLocalizations l10n) => l10n.demoAttorneyHeadlineCivil,
            ),
            (
              'Criminal defense and procedure',
              (AppLocalizations l10n) => l10n.demoAttorneyHeadlineCriminal,
            ),
            (
              'Family law and personal status',
              (AppLocalizations l10n) => l10n.demoAttorneyHeadlineFamily,
            ),
            (
              'Startup formation and advisory',
              (AppLocalizations l10n) => l10n.demoAttorneyHeadlineStartup,
            ),
          ];
      for (final (String raw, String Function(AppLocalizations) label)
          in values) {
        expect(localEn.attorneyHeadline(raw), label(en));
        expect(localAr.attorneyHeadline(raw), label(ar));
        expect(localAr.attorneyHeadline(raw), isNot(raw));
      }
      expect(localAr.attorneyHeadline('Cairo'), 'Cairo');
    });
  });

  group('audit summary cluster (Task 26)', () {
    test('the eight unique summaries map across the eleven render sites', () {
      final List<(String, String Function(AppLocalizations))> values =
          <(String, String Function(AppLocalizations))>[
            (
              'Organization created (metadata only)',
              (AppLocalizations l10n) => l10n.demoAuditOrganizationCreated,
            ),
            (
              'Member invited (metadata only)',
              (AppLocalizations l10n) => l10n.demoAuditMemberInvited,
            ),
            (
              'Member role changed (metadata only)',
              (AppLocalizations l10n) => l10n.demoAuditMemberRoleChanged,
            ),
            (
              'Membership suspended (metadata only)',
              (AppLocalizations l10n) => l10n.demoAuditMembershipSuspended,
            ),
            (
              'Demo account deleted (metadata only)',
              (AppLocalizations l10n) => l10n.demoAuditDemoAccountDeleted,
            ),
            (
              'role change',
              (AppLocalizations l10n) => l10n.demoAuditRoleChange,
            ),
            (
              'invitation sent',
              (AppLocalizations l10n) => l10n.demoAuditInvitationSent,
            ),
            (
              'suspension denied',
              (AppLocalizations l10n) => l10n.demoAuditSuspensionDenied,
            ),
          ];
      for (final (String raw, String Function(AppLocalizations) label)
          in values) {
        expect(localEn.auditSummary(raw), label(en));
        expect(localAr.auditSummary(raw), label(ar));
        expect(localAr.auditSummary(raw), isNot(raw));
      }
      // Identities/wire vocabulary stay verbatim: actions are never mapped.
      expect(localAr.auditSummary('member:role/change'), 'member:role/change');
    });
  });

  group('research recomposition helpers', () {
    test('corpus titles resolve across matters and documents', () {
      expect(
        localEn.corpusTitle('Demo acquisition review'),
        en.demoMatterTitle1,
      );
      expect(
        localEn.corpusTitle('Demo engagement letter'),
        en.demoDocumentTitle1,
      );
      expect(localEn.corpusTitle('Unknown row'), 'Unknown row');
    });

    test('source details reuse the enum labels', () {
      expect(
        localEn.sourceDetail('related demo matter'),
        en.researchRelatedMatter,
      );
      expect(localEn.sourceDetail('contract'), en.documentTypeContract);
      expect(localEn.sourceDetail('corporate'), en.areaCorporate);
      expect(localEn.sourceDetail('mystery'), 'mystery');
    });
  });

  group('research templates carry the mapped arguments', () {
    test('headline/summary/excerpt compose per locale', () {
      expect(en.researchHeadline('X'), 'Research note — X');
      expect(ar.researchHeadline('X'), isNot('Research note — X'));
      expect(en.demoMessageBody(7), contains('7'));
    });
  });
}
