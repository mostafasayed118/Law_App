// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'LegalHub';

  @override
  String get accessTitle => 'Temele erişin';

  @override
  String get accessBody =>
      'Bu başlangıç sürümü yalnızca yerel bir demo oturumu kullanır. Kimlik bilgileri toplanmaz veya gönderilmez.';

  @override
  String get continueAsDemo => 'Demo oturumuyla devam et';

  @override
  String get demoSessionNotice => 'Yalnızca geliştirme amaçlı demo oturumu';

  @override
  String get homeTitle => 'Temel çalışma alanı';

  @override
  String get homeBody =>
      'Bu yer tutucu tema, yerelleştirme, RTL bağlantısı ve paylaşılan görünüm durumlarını kanıtlar. Hukuki veya müşteri verisi yüklenmez.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get languageLabel => 'Dil';

  @override
  String get roleLabel => 'Yer tutucu rol';

  @override
  String get roleClient => 'Müşteri';

  @override
  String get roleAttorney => 'Avukat';

  @override
  String get rolePartner => 'Ortak';

  @override
  String get roleComplianceOfficer => 'Uyum görevlisi';

  @override
  String get roleResearchAnalyst => 'Araştırma analisti';

  @override
  String get roleAdmin => 'Yönetici';

  @override
  String get homeNavigation => 'Ana sayfa';

  @override
  String get settingsNavigation => 'Ayarlar';

  @override
  String get stateSuccess => 'Hazır';

  @override
  String get stateEmpty => 'Gösterilecek bir şey yok';

  @override
  String get stateError => 'Bu yer tutucu yüklenemedi';

  @override
  String get stateOffline => 'Çevrimdışı';

  @override
  String get stateUnauthorized => 'Erişim kullanılamıyor';

  @override
  String get stateLoading => 'Yükleniyor';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get foundationReady => 'Temel hazır';

  @override
  String get signOut => 'Demo oturumunu sonlandır';

  @override
  String get back => 'Geri';
}
