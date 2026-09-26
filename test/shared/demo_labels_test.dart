import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';

/// Pins the demo-copy localization contract (2026-09-24):
/// every known fake-gateway string maps to a localized label per locale,
/// unknown (server/user) strings pass through raw, and identities are
/// never rewritten.
void main() {
  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  group('notification labels (P1a)', () {
    test('known types map per locale', () {
      expect(demoNotificationType(en, 'invoice_status'), 'Invoice issued');
      expect(
        demoNotificationType(ar, 'invoice_status'),
        isNot('Invoice issued'),
      );
      expect(
        demoNotificationSummary(en, 'invoice_status', 'fallback'),
        'Demo notification — invoice issued',
      );
    });

    test('unknown server types pass through', () {
      expect(demoNotificationType(en, 'future_type'), 'future_type');
      expect(
        demoNotificationSummary(en, 'future_type', 'raw summary'),
        'raw summary',
      );
    });
  });

  group('matter titles cover every matterRef', () {
    test('all five synthetic titles map', () {
      expect(
        demoMatterTitle(en, 'Demo acquisition review'),
        en.demoMatterTitle1,
      );
      expect(
        demoMatterTitle(ar, 'Demo acquisition review'),
        isNot('Demo acquisition review'),
      );
      expect(
        demoMatterTitle(en, 'Startup formation advisory'),
        en.demoMatterTitle5,
      );
    });

    test('user-created titles pass through', () {
      expect(demoMatterTitle(en, 'My real case'), 'My real case');
    });
  });

  group('thread titles, bodies, authors', () {
    test('known thread titles map', () {
      expect(demoThreadTitle(en, 'Demo matter updates'), en.demoThreadTitle1);
      expect(
        demoThreadTitle(ar, 'Demo matter updates'),
        isNot('Demo matter updates'),
      );
    });

    test('synthetic bodies map with the message number', () {
      expect(
        demoMessageBody(
          en,
          'Demo message 3 — generic demo content, no real client or legal data.',
        ),
        en.demoMessageBody(3),
      );
    });

    test('user-composed bodies pass through', () {
      expect(demoMessageBody(en, 'Hello counselor'), 'Hello counselor');
    });

    test('generic authors map, real names pass through', () {
      expect(demoAuthorName(en, 'Demo attorney'), en.demoAuthorAttorney);
      expect(demoAuthorName(en, 'Demo client'), en.demoAuthorClient);
      expect(demoAuthorName(en, 'Layla Mansour'), 'Layla Mansour');
    });
  });

  group('documents, files, alerts, tasks, approvals, video', () {
    test('all corpora map with raw fallback', () {
      expect(
        demoDocumentTitle(en, 'Demo engagement letter'),
        en.demoDocumentTitle1,
      );
      expect(demoDocumentTitle(en, 'Unknown doc'), 'Unknown doc');
      expect(demoFileName(en, 'Demo retainer scan'), en.demoFileName1);
      expect(demoFileName(en, 'contract.pdf'), 'contract.pdf');
      expect(
        demoAlertTitle(en, 'Demo: review pending invitations'),
        en.demoAlertTitle1,
      );
      expect(demoTaskTitle(en, 'Demo: gather documents'), en.demoTaskTitle2);
      expect(
        demoApprovalReference(en, 'Demo role change'),
        en.demoApprovalRefRoleChange,
      );
      expect(
        demoApprovalReference(en, 'Demo engagement letter'),
        en.demoDocumentTitle1,
      );
      expect(
        demoApprovalEntityType(en, 'invitation'),
        en.demoApprovalEntityInvitation,
      );
      expect(
        demoVideoTopic(en, 'Contract review — kickoff'),
        en.demoVideoTopic1,
      );
    });
  });

  group('research recomposition helpers', () {
    test('corpus titles resolve across matters and documents', () {
      expect(
        demoCorpusTitle(en, 'Demo acquisition review'),
        en.demoMatterTitle1,
      );
      expect(
        demoCorpusTitle(en, 'Demo engagement letter'),
        en.demoDocumentTitle1,
      );
      expect(demoCorpusTitle(en, 'Unknown row'), 'Unknown row');
    });

    test('source details reuse the enum labels', () {
      expect(
        demoSourceDetail(en, 'related demo matter'),
        en.researchRelatedMatter,
      );
      expect(demoSourceDetail(en, 'contract'), en.documentTypeContract);
      expect(demoSourceDetail(en, 'corporate'), en.areaCorporate);
      expect(demoSourceDetail(en, 'mystery'), 'mystery');
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
