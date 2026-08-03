import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/discovery/presentation/discovery_entry_card.dart';
import 'package:legalhub/features/matters/presentation/matter_entry_card.dart';
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
  });
}
