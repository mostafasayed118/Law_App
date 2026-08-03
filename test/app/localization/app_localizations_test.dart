import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/state/view_state.dart';
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
  });
}
