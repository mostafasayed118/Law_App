import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/roles/user_role.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/presentation/discovery_entry_card.dart';
import 'package:legalhub/features/matters/presentation/matter_documents_section.dart';
import 'package:legalhub/features/matters/presentation/matter_entry_card.dart';
import 'package:legalhub/features/matters/presentation/matter_messages_section.dart';
import 'package:legalhub/features/messaging/presentation/message_count_chip.dart';
import 'package:legalhub/features/messaging/presentation/message_entry_card.dart';
import 'package:legalhub/features/search/presentation/search_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/view_state_view.dart';

void main() {
  group('AppLocalizations locale loading', () {
    test('resolves the TR locale from app_tr.arb', () {
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Proves app_tr.arb was loaded — real Turkish values, not the English
      // fallback (which would satisfy any isNotNull assertion).
      expect(tr.localeName, 'tr');
      expect(tr.stateLoading, 'Yükleniyor');
      expect(tr.retry, 'Yeniden dene');
      expect(tr.settingsTitle, 'Ayarlar');
      expect(tr.signInButton, 'Giriş Yap');
    });

    test('resolves all three supported locales', () {
      expect(lookupAppLocalizations(const Locale('en')).localeName, 'en');
      expect(lookupAppLocalizations(const Locale('ar')).localeName, 'ar');
      expect(lookupAppLocalizations(const Locale('tr')).localeName, 'tr');
    });

    test('TR is not a silent copy of EN for a shared key', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      expect(tr.stateLoading, isNot(en.stateLoading));
      expect(tr.retry, isNot(en.retry));
    });

    test('resolves the org surface keys in every locale (1.6 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      expect(en.orgTitle, 'Organization');
      expect(ar.orgTitle, 'المؤسسة');
      expect(tr.orgTitle, 'Kuruluş');
      expect(en.rosterTitle, 'Members');
      expect(tr.rosterTitle, 'Üyeler');
      expect(ar.rosterTitle, 'الأعضاء');
      // Real per-locale wording, not silent copies of EN.
      expect(tr.orgErrorLastPartner, isNot(en.orgErrorLastPartner));
      expect(ar.orgErrorLastPartner, isNot(en.orgErrorLastPartner));
      // Remove-member confirmation dialog (roadmap slice 1.4): title, confirm
      // action, and cancel all resolve per locale.
      expect(en.removeMemberConfirmTitle, 'Remove member?');
      expect(ar.removeMemberConfirmTitle, 'إزالة العضو؟');
      expect(tr.removeMemberConfirmTitle, 'Üye kaldırılsın mı?');
      expect(en.removeMemberConfirmAction, 'Remove');
      expect(ar.removeMemberConfirmAction, 'إزالة');
      expect(tr.removeMemberConfirmAction, 'Kaldır');
      expect(en.cancel, 'Cancel');
      expect(ar.cancel, 'إلغاء');
      expect(tr.cancel, 'İptal');
    });

    test('resolves the booking surface keys in every locale (5.3 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      expect(en.bookingTitle, 'Book a Consultation');
      expect(ar.bookingTitle, 'احجز استشارة');
      expect(tr.bookingTitle, 'Danışma Rezervasyonu');
      expect(en.bookingCategoryGeneral, 'General');
      expect(ar.bookingCategoryGeneral, 'عامة');
      expect(tr.bookingCategoryGeneral, 'Genel');
      expect(en.bookingSuccessTitle, 'Booking confirmed');
      expect(ar.bookingSuccessTitle, 'تم تأكيد الحجز');
      expect(tr.bookingSuccessTitle, 'Rezervasyon onaylandı');
      // Real per-locale wording, not silent copies of EN.
      expect(tr.bookingConfirmFailed, isNot(en.bookingConfirmFailed));
      expect(ar.bookingConfirmFailed, isNot(en.bookingConfirmFailed));
      // The local-only demo note resolves in every locale (D-B3/D-B6 copy).
      expect(tr.bookingLocalOnlyNote, isNot(en.bookingLocalOnlyNote));
      expect(ar.bookingLocalOnlyNote, isNot(en.bookingLocalOnlyNote));
    });

    test('resolves the sign-up check-inbox keys in every locale (4.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      expect(en.signUpCheckInboxTitle, 'Check Your Inbox');
      expect(ar.signUpCheckInboxTitle, 'تحقق من بريدك الوارد');
      expect(tr.signUpCheckInboxTitle, 'Gelen Kutunuzu Kontrol Edin');
      expect(en.signUpCheckInboxAction, 'Continue to Sign In');
      expect(ar.signUpCheckInboxAction, 'المتابعة إلى تسجيل الدخول');
      expect(tr.signUpCheckInboxAction, 'Girişe Geç');
      // Real per-locale wording, not silent copies of EN.
      expect(tr.signUpCheckInboxBody, isNot(en.signUpCheckInboxBody));
      expect(ar.signUpCheckInboxBody, isNot(en.signUpCheckInboxBody));
      expect(tr.signUpCheckInboxTitle, isNot(en.signUpCheckInboxTitle));
    });

    test('resolves the discovery keys in every locale (6.3 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Search surface (slice 6.1).
      expect(en.discoveryTitle, 'Find an Attorney');
      expect(ar.discoveryTitle, 'ابحث عن محامٍ');
      expect(tr.discoveryTitle, 'Avukat Bul');
      expect(en.discoverySearchHint, 'Search by name or practice area');
      expect(ar.discoverySearchHint, 'ابحث بالاسم أو مجال الممارسة');
      expect(tr.discoverySearchHint, 'İsme veya uygulama alanına göre ara');
      expect(en.discoveryFilterAll, 'All');
      expect(ar.discoveryFilterAll, 'الكل');
      expect(tr.discoveryFilterAll, 'Tümü');
      expect(en.discoveryEmpty, 'No attorneys match your search.');
      expect(ar.discoveryEmpty, 'لا يوجد محامون يطابقون بحثك.');
      expect(tr.discoveryEmpty, 'Aramanızla eşleşen avukat yok.');
      expect(en.discoveryError, 'Unable to load attorneys.');
      expect(ar.discoveryError, 'تعذّر تحميل المحامين.');
      expect(tr.discoveryError, 'Avukatlar yüklenemedi.');
      expect(
        en.discoveryLocalOnlyNote,
        'Demo mode — synthetic profiles only. No real attorneys are listed '
        'or contacted.',
      );
      expect(
        ar.discoveryLocalOnlyNote,
        'وضع تجريبي — ملفات تعريفية اصطناعية فقط. لا يتم عرض محامين حقيقيين أو '
        'التواصل معهم.',
      );
      expect(
        tr.discoveryLocalOnlyNote,
        'Demo modu — yalnızca sentetik profiller. Gerçek avukatlar '
        'listelenmez veya iletişime geçilmez.',
      );

      // Home entry (slice 6.1).
      expect(en.discoveryEntryTitle, 'Find an attorney');
      expect(ar.discoveryEntryTitle, 'ابحث عن محامٍ');
      expect(tr.discoveryEntryTitle, 'Bir avukat bul');
      expect(
        en.discoveryEntrySubtitle,
        'Browse demo attorney profiles — development demo.',
      );
      expect(
        ar.discoveryEntrySubtitle,
        'تصفح ملفات المحامين التجريبية — عرض تجريبي للتطوير.',
      );
      expect(
        tr.discoveryEntrySubtitle,
        'Demo avukat profillerine göz atın — geliştirme demosu.',
      );

      // Profile surface + booking hook (slice 6.2).
      expect(en.discoveryProfileTitle, 'Attorney profile');
      expect(ar.discoveryProfileTitle, 'ملف المحامي');
      expect(tr.discoveryProfileTitle, 'Avukat profili');
      expect(en.discoveryProfileNotFound, 'Attorney not found.');
      expect(ar.discoveryProfileNotFound, 'المحامي غير موجود.');
      expect(tr.discoveryProfileNotFound, 'Avukat bulunamadı.');
      expect(en.discoveryProfileBio, 'About');
      expect(ar.discoveryProfileBio, 'نبذة');
      expect(tr.discoveryProfileBio, 'Hakkında');
      expect(en.discoveryProfileBook, 'Book with this attorney');
      expect(ar.discoveryProfileBook, 'احجز مع هذا المحامي');
      expect(tr.discoveryProfileBook, 'Bu avukatla rezervasyon yap');
      expect(en.bookingSummaryAttorney, 'Attorney');
      expect(ar.bookingSummaryAttorney, 'المحامي');
      expect(tr.bookingSummaryAttorney, 'Avukat');
      expect(
        en.bookingAttorneyPrefill('Layla Mansour'),
        'Booking with Layla Mansour',
      );
      expect(
        ar.bookingAttorneyPrefill('Layla Mansour'),
        'الحجز مع Layla Mansour',
      );
      expect(
        tr.bookingAttorneyPrefill('Layla Mansour'),
        'Layla Mansour ile rezervasyon',
      );

      // Practice-area labels reused by the discovery surfaces.
      expect(en.areaCorporate, 'Corporate');
      expect(ar.areaCorporate, 'شركات');
      expect(tr.areaCorporate, 'Kurumsal');
      expect(en.areaCivil, 'Civil');
      expect(ar.areaCivil, 'مدني');
      expect(tr.areaCivil, 'Hukuk');
      expect(en.areaCriminal, 'Criminal');
      expect(ar.areaCriminal, 'جنائي');
      expect(tr.areaCriminal, 'Ceza');
      expect(en.areaFamily, 'Family');
      expect(ar.areaFamily, 'أحوال شخصية');
      expect(tr.areaFamily, 'Aile');

      // Real per-locale wording, not silent copies of EN.
      expect(tr.discoveryTitle, isNot(en.discoveryTitle));
      expect(ar.discoveryEmpty, isNot(en.discoveryEmpty));
      expect(tr.discoveryProfileBook, isNot(en.discoveryProfileBook));
      expect(
        ar.bookingAttorneyPrefill('X'),
        isNot(en.bookingAttorneyPrefill('X')),
      );
    });

    test(
      'discovery copy is local-only wording, no legal-advice claim (R3)',
      () {
        final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

        // AC-6/R3 pin (spec §6 row 152): the demo/local-only framing is
        // literal copy, and it must not drift into legal-advice or
        // compliance-claim territory. The exact per-locale wording is pinned
        // in the 6.3 resolution test above; this test only guards the
        // framing rails.
        expect(en.discoveryEntrySubtitle, contains('demo'));
        expect(en.discoveryEntrySubtitle, isNot(contains('legal advice')));
        expect(en.discoveryLocalOnlyNote, isNot(contains('legal advice')));
      },
    );

    test('resolves the matter keys in every locale (7.3 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // List surface (slice 7.1).
      expect(en.matterTitle, 'Matters');
      expect(ar.matterTitle, 'القضايا');
      expect(tr.matterTitle, 'Davalar');
      expect(en.matterFilterAll, 'All');
      expect(ar.matterFilterAll, 'الكل');
      expect(tr.matterFilterAll, 'Tümü');
      expect(en.matterStatusOpen, 'Open');
      expect(ar.matterStatusOpen, 'مفتوحة');
      expect(tr.matterStatusOpen, 'Açık');
      expect(en.matterStatusActive, 'Active');
      expect(ar.matterStatusActive, 'نشطة');
      expect(tr.matterStatusActive, 'Aktif');
      expect(en.matterStatusClosed, 'Closed');
      expect(ar.matterStatusClosed, 'مغلقة');
      expect(tr.matterStatusClosed, 'Kapalı');
      expect(en.matterEmpty, 'No matters match the filter.');
      expect(ar.matterEmpty, 'لا توجد قضايا تطابق عامل التصفية.');
      expect(tr.matterEmpty, 'Filtreyle eşleşen dava yok.');
      expect(en.matterError, 'Unable to load matters.');
      expect(ar.matterError, 'تعذّر تحميل القضايا.');
      expect(tr.matterError, 'Davalar yüklenemedi.');
      expect(
        en.matterLocalOnlyNote,
        'Demo mode — synthetic matters only. No real cases are listed.',
      );
      expect(
        ar.matterLocalOnlyNote,
        'وضع تجريبي — قضايا اصطناعية فقط. لا يتم عرض قضايا حقيقية.',
      );
      expect(
        tr.matterLocalOnlyNote,
        'Demo modu — yalnızca sentetik davalar. Gerçek davalar listelenmez.',
      );

      // Home entry (slice 7.1).
      expect(en.matterEntryTitle, 'My matters');
      expect(ar.matterEntryTitle, 'قضاياي');
      expect(tr.matterEntryTitle, 'Davalarım');
      expect(
        en.matterEntrySubtitle,
        'Browse demo matter files — development demo.',
      );
      expect(
        ar.matterEntrySubtitle,
        'تصفح ملفات القضايا التجريبية — عرض تجريبي للتطوير.',
      );
      expect(
        tr.matterEntrySubtitle,
        'Demo dava dosyalarına göz atın — geliştirme demosu.',
      );

      // Details surface (slice 7.2).
      expect(en.matterDetailsTitle, 'Matter details');
      expect(ar.matterDetailsTitle, 'تفاصيل القضية');
      expect(tr.matterDetailsTitle, 'Dava detayları');
      expect(en.matterDetailsNotFound, 'Matter not found.');
      expect(ar.matterDetailsNotFound, 'القضية غير موجودة.');
      expect(tr.matterDetailsNotFound, 'Dava bulunamadı.');
      expect(en.matterDetailsPracticeArea, 'Practice area');
      expect(ar.matterDetailsPracticeArea, 'مجال الممارسة');
      expect(tr.matterDetailsPracticeArea, 'Çalışma alanı');
      expect(en.matterDetailsAssignedAttorney, 'Assigned attorney');
      expect(ar.matterDetailsAssignedAttorney, 'المحامي المكلَّف');
      expect(tr.matterDetailsAssignedAttorney, 'Atanan avukat');
      expect(en.matterDetailsCreated, 'Created');
      expect(ar.matterDetailsCreated, 'تاريخ الإنشاء');
      expect(tr.matterDetailsCreated, 'Oluşturulma');

      // Real per-locale wording, not silent copies of EN.
      expect(tr.matterTitle, isNot(en.matterTitle));
      expect(ar.matterEmpty, isNot(en.matterEmpty));
      expect(tr.matterDetailsTitle, isNot(en.matterDetailsTitle));
      expect(ar.matterDetailsCreated, isNot(en.matterDetailsCreated));
      expect(tr.matterLocalOnlyNote, isNot(en.matterLocalOnlyNote));
      expect(ar.matterLocalOnlyNote, isNot(en.matterLocalOnlyNote));
    });

    test('matter copy is local-only wording, no legal-advice claim (AC-6)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      // AC-6 pin (matter_dashboard_scope_2026-08-03.md §5 AC-6, risk R1):
      // the demo/local-only framing is literal copy, and it must not drift
      // into legal-advice or compliance-claim territory. The exact
      // per-locale wording is pinned in the 7.3 resolution test above; this
      // test only guards the framing rails.
      expect(en.matterEntrySubtitle, contains('demo'));
      expect(en.matterEntrySubtitle, isNot(contains('legal advice')));
      expect(en.matterLocalOnlyNote, isNot(contains('legal advice')));
    });

    test('resolves the vault keys in every locale (8.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Vault list surface (slice 8.1).
      expect(en.vaultTitle, 'Documents');
      expect(ar.vaultTitle, 'المستندات');
      expect(tr.vaultTitle, 'Belgeler');
      expect(en.vaultEmpty, 'No documents are available.');
      expect(ar.vaultEmpty, 'لا توجد مستندات متاحة.');
      expect(tr.vaultEmpty, 'Kullanılabilir belge yok.');
      expect(en.vaultError, 'Unable to load documents.');
      expect(ar.vaultError, 'تعذّر تحميل المستندات.');
      expect(tr.vaultError, 'Belgeler yüklenemedi.');
      expect(
        en.vaultLocalOnlyNote,
        'Demo mode — synthetic document metadata only. No real files are listed.',
      );
      expect(
        ar.vaultLocalOnlyNote,
        'وضع تجريبي — بيانات وصفية اصطناعية للمستندات فقط. لا يتم عرض ملفات حقيقية.',
      );
      expect(
        tr.vaultLocalOnlyNote,
        'Demo modu — yalnızca sentetik belge meta verileri. Gerçek dosyalar listelenmez.',
      );

      // Home entry (slice 8.1).
      expect(en.vaultEntryTitle, 'Document vault');
      expect(ar.vaultEntryTitle, 'خزنة المستندات');
      expect(tr.vaultEntryTitle, 'Belge kasası');
      expect(
        en.vaultEntrySubtitle,
        'Browse demo document metadata — development demo.',
      );
      expect(
        ar.vaultEntrySubtitle,
        'تصفح البيانات الوصفية للمستندات التجريبية — عرض تجريبي للتطوير.',
      );
      expect(
        tr.vaultEntrySubtitle,
        'Demo belge meta verilerine göz atın — geliştirme demosu.',
      );

      // Document-type labels (slice 8.1 type chips).
      expect(en.documentTypeContract, 'Contract');
      expect(ar.documentTypeContract, 'عقد');
      expect(tr.documentTypeContract, 'Sözleşme');
      expect(en.documentTypeBrief, 'Brief');
      expect(ar.documentTypeBrief, 'مذكرة');
      expect(tr.documentTypeBrief, 'Özet');
      expect(en.documentTypeEvidence, 'Evidence');
      expect(ar.documentTypeEvidence, 'دليل');
      expect(tr.documentTypeEvidence, 'Kanıt');
      expect(en.documentTypeCorrespondence, 'Correspondence');
      expect(ar.documentTypeCorrespondence, 'مراسلات');
      expect(tr.documentTypeCorrespondence, 'Yazışma');

      // Real per-locale wording, not silent copies of EN.
      expect(tr.vaultTitle, isNot(en.vaultTitle));
      expect(ar.vaultEmpty, isNot(en.vaultEmpty));
      expect(tr.vaultEntryTitle, isNot(en.vaultEntryTitle));
      expect(ar.vaultLocalOnlyNote, isNot(en.vaultLocalOnlyNote));
      expect(tr.documentTypeContract, isNot(en.documentTypeContract));
      expect(
        ar.documentTypeCorrespondence,
        isNot(en.documentTypeCorrespondence),
      );
    });

    test(
      'vault copy is local-only wording, no e-signature/legal-advice claim (AC-5)',
      () {
        final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

        // AC-5 pin (document_vault_scope_2026-08-03.md §5 AC-5, risk R1):
        // the demo/local-only framing is literal copy, and it must not drift
        // into legal-advice or e-signature-claim territory. The exact
        // per-locale wording is pinned in the 8.2 resolution test above;
        // this test only guards the framing rails.
        expect(en.vaultEntrySubtitle, contains('demo'));
        expect(en.vaultEntrySubtitle, isNot(contains('legal advice')));
        expect(en.vaultLocalOnlyNote, isNot(contains('legal advice')));
        expect(en.vaultEntrySubtitle, isNot(contains('e-signature')));
        expect(en.vaultLocalOnlyNote, isNot(contains('e-signature')));
      },
    );

    test('resolves the messaging keys in every locale (9.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Thread-list surface (slice 9.1).
      expect(en.messagesTitle, 'Messages');
      expect(ar.messagesTitle, 'الرسائل');
      expect(tr.messagesTitle, 'Mesajlar');
      expect(en.messagesEmpty, 'No message threads are available.');
      expect(ar.messagesEmpty, 'لا توجد محادثات متاحة.');
      expect(tr.messagesEmpty, 'Kullanılabilir mesaj dizisi yok.');
      expect(en.messagesError, 'Unable to load message threads.');
      expect(ar.messagesError, 'تعذّر تحميل المحادثات.');
      expect(tr.messagesError, 'Mesaj dizileri yüklenemedi.');
      expect(
        en.messagesLocalOnlyNote,
        'Demo mode — synthetic thread metadata only. No real messages are listed.',
      );
      expect(
        ar.messagesLocalOnlyNote,
        'وضع تجريبي — بيانات وصفية اصطناعية للمحادثات فقط. لا يتم عرض رسائل حقيقية.',
      );
      expect(
        tr.messagesLocalOnlyNote,
        'Demo modu — yalnızca sentetik dizgi meta verileri. Gerçek mesajlar listelenmez.',
      );

      // Home entry (slice 9.1).
      expect(en.messagesEntryTitle, 'Messages');
      expect(ar.messagesEntryTitle, 'الرسائل');
      expect(tr.messagesEntryTitle, 'Mesajlar');
      expect(
        en.messagesEntrySubtitle,
        'Browse demo message threads — development demo.',
      );
      expect(
        ar.messagesEntrySubtitle,
        'تصفح محادثات تجريبية — عرض تجريبي للتطوير.',
      );
      expect(
        tr.messagesEntrySubtitle,
        'Demo mesaj dizilerine göz atın — geliştirme demosu.',
      );

      // Message-count chip label (slice 9.1) — a count, never content.
      expect(en.messagesMessageCount(12), '12 messages');
      expect(ar.messagesMessageCount(12), '12 رسائل');
      expect(tr.messagesMessageCount(12), '12 mesaj');

      // Real per-locale wording, not silent copies of EN.
      expect(tr.messagesTitle, isNot(en.messagesTitle));
      expect(ar.messagesEmpty, isNot(en.messagesEmpty));
      expect(tr.messagesEntryTitle, isNot(en.messagesEntryTitle));
      expect(ar.messagesLocalOnlyNote, isNot(en.messagesLocalOnlyNote));
      expect(ar.messagesMessageCount(12), isNot(en.messagesMessageCount(12)));
    });

    test('messaging copy is local-only wording, no send/realtime/legal-advice '
        'claim (AC-5)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      // AC-5 pin (matter_messaging_scope_2026-08-03.md §5 AC-5, risk R1):
      // the demo/local-only framing is literal copy, and it must not drift
      // into legal-advice, send, or realtime/delivery-claim territory. The
      // exact per-locale wording is pinned in the 9.2 resolution test
      // above; this test only guards the framing rails.
      expect(en.messagesEntrySubtitle, contains('demo'));
      expect(en.messagesEntrySubtitle, isNot(contains('legal advice')));
      expect(en.messagesLocalOnlyNote, isNot(contains('legal advice')));
      expect(en.messagesEntrySubtitle, isNot(contains('send')));
      expect(en.messagesLocalOnlyNote, isNot(contains('send')));
      expect(en.messagesEntrySubtitle, isNot(contains('realtime')));
      expect(en.messagesLocalOnlyNote, isNot(contains('realtime')));
      expect(en.messagesLocalOnlyNote, isNot(contains('delivery')));
    });

    test('resolves the workspace keys in every locale (10.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Workspace section titles + per-matter empty copy (slice 10.1).
      expect(en.matterWorkspaceDocumentsTitle, 'Documents');
      expect(ar.matterWorkspaceDocumentsTitle, 'المستندات');
      expect(tr.matterWorkspaceDocumentsTitle, 'Belgeler');
      expect(en.matterWorkspaceMessagesTitle, 'Messages');
      expect(ar.matterWorkspaceMessagesTitle, 'الرسائل');
      expect(tr.matterWorkspaceMessagesTitle, 'Mesajlar');
      expect(
        en.matterWorkspaceDocumentsEmpty,
        'No documents are available for this matter.',
      );
      expect(
        ar.matterWorkspaceDocumentsEmpty,
        'لا توجد مستندات متاحة لهذه القضية.',
      );
      expect(
        tr.matterWorkspaceDocumentsEmpty,
        'Bu dava için kullanılabilir belge yok.',
      );
      expect(
        en.matterWorkspaceMessagesEmpty,
        'No message threads are available for this matter.',
      );
      expect(
        ar.matterWorkspaceMessagesEmpty,
        'لا توجد محادثات متاحة لهذه القضية.',
      );
      expect(
        tr.matterWorkspaceMessagesEmpty,
        'Bu dava için kullanılabilir mesaj dizisi yok.',
      );

      // Real per-locale wording, not silent copies of EN.
      expect(
        tr.matterWorkspaceDocumentsEmpty,
        isNot(en.matterWorkspaceDocumentsEmpty),
      );
      expect(
        ar.matterWorkspaceMessagesEmpty,
        isNot(en.matterWorkspaceMessagesEmpty),
      );
      expect(
        ar.matterWorkspaceDocumentsTitle,
        isNot(en.matterWorkspaceDocumentsTitle),
      );
      expect(
        tr.matterWorkspaceMessagesTitle,
        isNot(en.matterWorkspaceMessagesTitle),
      );

      // Billing slice (D-BI5): the invoices section title + empty copy +
      // status labels resolve in every locale.
      expect(en.matterWorkspaceInvoicesTitle, 'Invoices');
      expect(ar.matterWorkspaceInvoicesTitle, 'الفواتير');
      expect(tr.matterWorkspaceInvoicesTitle, 'Faturalar');
      expect(
        en.matterWorkspaceInvoicesEmpty,
        'No invoices are available for this matter.',
      );
      expect(
        ar.matterWorkspaceInvoicesEmpty,
        'لا توجد فواتير متاحة لهذه القضية.',
      );
      expect(
        tr.matterWorkspaceInvoicesEmpty,
        'Bu dava için kullanılabilir fatura yok.',
      );
      expect(en.invoiceStatusIssued, 'Issued');
      expect(ar.invoiceStatusIssued, 'صادرة');
      expect(tr.invoiceStatusIssued, 'Düzenlendi');
      expect(en.invoiceStatusPaid, 'Paid');
      expect(ar.invoiceStatusPaid, 'مدفوعة');
      expect(tr.invoiceStatusPaid, 'Ödendi');
      expect(
        tr.matterWorkspaceInvoicesTitle,
        isNot(en.matterWorkspaceInvoicesTitle),
      );
    });

    test('workspace copy is local-only wording, no legal-advice/realtime/send '
        'claim (AC-5)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      // AC-5 pin (matter_workspace_scope_2026-08-04.md §5 AC-5, risk R1):
      // the per-matter copy is empty-state wording over the synthetic
      // lists, and it must not drift into legal-advice, e-signature,
      // send, or realtime/delivery-claim territory. The exact per-locale
      // wording is pinned in the 10.2 resolution test above; this test
      // only guards the framing rails.
      expect(en.matterWorkspaceDocumentsEmpty, isNot(contains('legal advice')));
      expect(en.matterWorkspaceDocumentsEmpty, isNot(contains('e-signature')));
      expect(en.matterWorkspaceMessagesEmpty, isNot(contains('legal advice')));
      expect(en.matterWorkspaceMessagesEmpty, isNot(contains('send')));
      expect(en.matterWorkspaceMessagesEmpty, isNot(contains('realtime')));
      expect(en.matterWorkspaceMessagesEmpty, isNot(contains('delivery')));
      // The invoices empty copy must not drift into payment/charge framing
      // (D-11 — no live payment in MVP; the metadata-only line holds).
      expect(en.matterWorkspaceInvoicesEmpty, isNot(contains('pay')));
      expect(en.matterWorkspaceInvoicesEmpty, isNot(contains('charge')));
    });

    test('resolves the search keys in every locale (11.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Search surface (slice 11.1). The placeholder predates this phase and
      // is reused verbatim (D-S6).
      expect(en.searchPlaceholder, 'Find a lawyer or legal topic...');
      expect(ar.searchPlaceholder, 'ابحث عن محامٍ أو موضوع قانوني...');
      expect(tr.searchPlaceholder, 'Avukat veya hukuki konu bulun...');
      expect(en.searchTitle, 'Search');
      expect(ar.searchTitle, 'بحث');
      expect(tr.searchTitle, 'Ara');
      expect(
        en.searchNoQuery,
        'Type a search term to find demo matters, documents, messages, or '
        'attorneys.',
      );
      expect(
        ar.searchNoQuery,
        'اكتب كلمة بحث للعثور على القضايا أو المستندات أو الرسائل أو '
        'المحامين التجريبية.',
      );
      expect(
        tr.searchNoQuery,
        'Demo konular, belgeler, mesajlar veya avukatlar bulmak için bir '
        'arama terimi yazın.',
      );
      expect(en.searchEmpty, 'No results match your search.');
      expect(ar.searchEmpty, 'لا توجد نتائج مطابقة لبحثك.');
      expect(tr.searchEmpty, 'Aramanızla eşleşen sonuç yok.');
      expect(en.searchError, 'Unable to run the search.');
      expect(ar.searchError, 'تعذّر تشغيل البحث.');
      expect(tr.searchError, 'Arama çalıştırılamadı.');
      expect(
        en.searchLocalOnlyNote,
        'Demo mode — results come from synthetic lists only. No real data is '
        'searched.',
      );
      expect(
        ar.searchLocalOnlyNote,
        'وضع تجريبي — النتائج من قوائم اصطناعية فقط. لا يتم البحث في أي '
        'بيانات حقيقية.',
      );
      expect(
        tr.searchLocalOnlyNote,
        'Demo modu — sonuçlar yalnızca sentetik listelerden gelir. Gerçek '
        'veri aranmaz.',
      );

      // Real per-locale wording, not silent copies of EN.
      expect(tr.searchTitle, isNot(en.searchTitle));
      expect(ar.searchEmpty, isNot(en.searchEmpty));
      expect(tr.searchError, isNot(en.searchError));
      expect(ar.searchLocalOnlyNote, isNot(en.searchLocalOnlyNote));
      expect(tr.searchNoQuery, isNot(en.searchNoQuery));
    });

    test('search copy is local-only wording, no legal-advice/send/realtime '
        'claim (AC-5)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      // AC-5 pin (unified_search_scope_2026-08-04.md §5 AC-5, risk R1):
      // the demo/local-only framing is literal copy, and it must not drift
      // into legal-advice, send, or realtime/delivery-claim territory. The
      // exact per-locale wording is pinned in the 11.2 resolution test
      // above; this test only guards the framing rails.
      expect(en.searchNoQuery, contains('demo'));
      expect(en.searchLocalOnlyNote, contains('synthetic'));
      expect(en.searchNoQuery, isNot(contains('legal advice')));
      expect(en.searchLocalOnlyNote, isNot(contains('legal advice')));
      expect(en.searchLocalOnlyNote, isNot(contains('send')));
      expect(en.searchLocalOnlyNote, isNot(contains('realtime')));
      expect(en.searchLocalOnlyNote, isNot(contains('delivery')));
    });

    test('resolves the viewMatter key in every locale (12.2 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Reverse cross-link affordance copy (slices 12.0/12.1, D-C2): the
      // compact "View matter" chip label on resolved vault and messages
      // rows. Shipped with 12.0 (16e9b67), consumed by 12.1 (69622ce).
      expect(en.viewMatter, 'View matter');
      expect(ar.viewMatter, 'عرض القضية');
      expect(tr.viewMatter, 'Davayı görüntüle');

      // Real per-locale wording, not silent copies of EN.
      expect(tr.viewMatter, isNot(en.viewMatter));
      expect(ar.viewMatter, isNot(en.viewMatter));
    });

    test('resolves the org-audit keys in every locale (2026-08-09 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // Partner org-audit surface (partner_org_audit_scope_2026-08-09.md):
      // exact copy per locale, plus the no-silent-EN-copy guards.
      expect(en.orgAuditTitle, 'Audit trail');
      expect(ar.orgAuditTitle, 'سجل التدقيق');
      expect(tr.orgAuditTitle, 'Denetim kaydı');

      expect(en.orgAuditEmpty, 'No audit events recorded yet.');
      expect(ar.orgAuditEmpty, 'لم يتم تسجيل أي أحداث تدقيق حتى الآن.');
      expect(tr.orgAuditEmpty, 'Henüz hiçbir denetim olayı kaydedilmedi.');

      expect(
        en.orgAuditDenied,
        "You do not have permission to view this organization's audit trail.",
      );
      expect(
        ar.orgAuditDenied,
        'ليس لديك صلاحية للاطلاع على سجل تدقيق هذه المؤسسة.',
      );
      expect(
        tr.orgAuditDenied,
        'Bu kuruluşun denetim kaydını görüntüleme izniniz yok.',
      );

      expect(en.orgAuditError, 'Unable to load the audit trail.');
      expect(ar.orgAuditError, 'تعذّر تحميل سجل التدقيق.');
      expect(tr.orgAuditError, 'Denetim kaydı yüklenemedi.');

      expect(en.orgAuditRetry, 'Try again');
      expect(ar.orgAuditRetry, 'إعادة المحاولة');
      expect(tr.orgAuditRetry, 'Tekrar dene');

      expect(en.orgAuditHubEntry, 'View audit trail');
      expect(ar.orgAuditHubEntry, 'عرض سجل التدقيق');
      expect(tr.orgAuditHubEntry, 'Denetim kaydını görüntüle');

      expect(en.orgAuditOutcomeAllowed, 'Allowed');
      expect(ar.orgAuditOutcomeAllowed, 'مسموح');
      expect(tr.orgAuditOutcomeAllowed, 'İzinli');

      expect(en.orgAuditOutcomeDenied, 'Denied');
      expect(ar.orgAuditOutcomeDenied, 'مرفوض');
      expect(tr.orgAuditOutcomeDenied, 'Reddedildi');

      // Real per-locale wording, not silent copies of EN (mirrors the 12.2
      // guard style).
      expect(tr.orgAuditTitle, isNot(en.orgAuditTitle));
      expect(ar.orgAuditTitle, isNot(en.orgAuditTitle));
      expect(tr.orgAuditEmpty, isNot(en.orgAuditEmpty));
      expect(ar.orgAuditEmpty, isNot(en.orgAuditEmpty));
      expect(tr.orgAuditDenied, isNot(en.orgAuditDenied));
      expect(ar.orgAuditDenied, isNot(en.orgAuditDenied));
      expect(tr.orgAuditHubEntry, isNot(en.orgAuditHubEntry));
      expect(ar.orgAuditHubEntry, isNot(en.orgAuditHubEntry));
    });

    test('resolves the recovery error key in every locale (P3.1 pin)', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

      // The one generic, non-enumerating recovery denial (plan §7): every
      // recovery failure renders this localized notice, so the copy is
      // pinned per locale and must never be a silent EN copy.
      expect(
        en.recoveryErrorNotice,
        "We couldn't complete that request. Please try again.",
      );
      expect(
        ar.recoveryErrorNotice,
        'تعذر إكمال هذا الطلب. يرجى المحاولة مرة أخرى.',
      );
      expect(
        tr.recoveryErrorNotice,
        'Bu istek tamamlanamadı. Lütfen tekrar deneyin.',
      );

      // Real per-locale wording, not silent copies of EN.
      expect(tr.recoveryErrorNotice, isNot(en.recoveryErrorNotice));
      expect(ar.recoveryErrorNotice, isNot(en.recoveryErrorNotice));
    });
  });

  group('AppLocalizations widget rendering', () {
    testWidgets('renders Turkish text when the app locale is tr', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: const ViewStateView<String>(state: ViewLoading<String>()),
          ),
        ),
      );

      // The shared ViewStateView renders the TR translation of stateLoading.
      expect(find.text('Yükleniyor'), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('renders the discovery entry card in AR and TR, not the EN '
        'fallback (6.3 pin)', (tester) async {
      Future<void> pumpAt(Locale locale) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiscoveryEntryCard(onTap: null)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpAt(const Locale('ar'));
      expect(find.text('ابحث عن محامٍ'), findsOneWidget);
      expect(find.text('Find an attorney'), findsNothing);

      await pumpAt(const Locale('tr'));
      expect(find.text('Bir avukat bul'), findsOneWidget);
      expect(find.text('Find an attorney'), findsNothing);
    });

    testWidgets(
      'renders the matter entry card in AR and TR, not the EN fallback '
      '(7.3 pin)',
      (tester) async {
        Future<void> pumpAt(Locale locale) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: MatterEntryCard(onTap: null)),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(const Locale('ar'));
        expect(find.text('قضاياي'), findsOneWidget);
        expect(find.text('My matters'), findsNothing);

        await pumpAt(const Locale('tr'));
        expect(find.text('Davalarım'), findsOneWidget);
        expect(find.text('My matters'), findsNothing);
      },
    );

    testWidgets(
      'renders the message entry card in AR and TR, not the EN fallback '
      '(9.2 pin)',
      (tester) async {
        Future<void> pumpAt(Locale locale) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: MessageEntryCard(onTap: null)),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(const Locale('ar'));
        expect(find.text('الرسائل'), findsOneWidget);
        expect(find.text('Messages'), findsNothing);

        await pumpAt(const Locale('tr'));
        expect(find.text('Mesajlar'), findsOneWidget);
        expect(find.text('Messages'), findsNothing);
      },
    );

    testWidgets(
      'renders the message count chip with the AR and TR label, not the EN '
      'fallback (9.2 pin)',
      (tester) async {
        Future<void> pumpAt(Locale locale, String label) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: MessageCountChip(label: label)),
            ),
          );
          await tester.pumpAndSettle();
        }

        final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
        final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
        final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

        await pumpAt(const Locale('ar'), ar.messagesMessageCount(5));
        expect(find.text('5 رسائل'), findsOneWidget);
        expect(find.text('5 messages'), findsNothing);

        await pumpAt(const Locale('tr'), tr.messagesMessageCount(5));
        expect(find.text('5 mesaj'), findsOneWidget);
        expect(find.text('5 messages'), findsNothing);

        // Sanity: the EN label itself resolves (used by the list tiles).
        expect(en.messagesMessageCount(5), '5 messages');
      },
    );

    testWidgets(
      'renders the matter documents section empty copy in AR and TR, not '
      'the EN fallback (10.2 pin)',
      (tester) async {
        configureDependencies();
        addTearDown(resetServiceLocator);

        Future<void> pumpAt(Locale locale) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                // An unmatched matterRef filters the synthetic list to the
                // per-matter empty state (D-W2: every known matter owns at
                // least one document, so only an unknown ref can empty it).
                body: const MatterDocumentsSection(matterRef: 'no-such-matter'),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(const Locale('ar'));
        expect(find.text('لا توجد مستندات متاحة لهذه القضية.'), findsOneWidget);
        expect(
          find.text('No documents are available for this matter.'),
          findsNothing,
        );

        await pumpAt(const Locale('tr'));
        expect(
          find.text('Bu dava için kullanılabilir belge yok.'),
          findsOneWidget,
        );
        expect(
          find.text('No documents are available for this matter.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders the matter messages section empty copy in AR and TR, not '
      'the EN fallback (10.2 pin)',
      (tester) async {
        configureDependencies();
        addTearDown(resetServiceLocator);

        Future<void> pumpAt(Locale locale) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                // An unmatched matterRef filters the synthetic list to the
                // per-matter empty state.
                body: const MatterMessagesSection(matterRef: 'no-such-matter'),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(const Locale('ar'));
        expect(find.text('لا توجد محادثات متاحة لهذه القضية.'), findsOneWidget);
        expect(
          find.text('No message threads are available for this matter.'),
          findsNothing,
        );

        await pumpAt(const Locale('tr'));
        expect(
          find.text('Bu dava için kullanılabilir mesaj dizisi yok.'),
          findsOneWidget,
        );
        expect(
          find.text('No message threads are available for this matter.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'renders the search empty copy in AR and TR, not the EN fallback '
      '(11.2 pin)',
      (tester) async {
        configureDependencies();
        addTearDown(resetServiceLocator);

        Future<void> pumpAt(Locale locale) async {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SearchScreen(
                capabilities: roleCapabilities[UserRole.client]!,
                // A query with no matches lands on the localized empty state.
                initialQuery: 'zzz',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(const Locale('ar'));
        expect(find.text('لا توجد نتائج مطابقة لبحثك.'), findsOneWidget);
        expect(find.text('No results match your search.'), findsNothing);

        await pumpAt(const Locale('tr'));
        expect(find.text('Aramanızla eşleşen sonuç yok.'), findsOneWidget);
        expect(find.text('No results match your search.'), findsNothing);
      },
    );
  });
}
