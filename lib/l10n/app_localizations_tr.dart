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

  @override
  String get signInWelcome => 'Tekrar Hoş Geldiniz';

  @override
  String get signInSubtitle =>
      'Güvenli hukuki çalışma istasyonunuza erişmek için giriş yapın.';

  @override
  String get emailLabel => 'E-posta Adresi';

  @override
  String get emailPlaceholder => 'örn. counsel@firm.com';

  @override
  String get passwordLabel => 'Parola';

  @override
  String get passwordPlaceholder => '••••••••';

  @override
  String get forgotPassword => 'Parolanızı mı unuttunuz?';

  @override
  String get signInButton => 'Giriş Yap';

  @override
  String get orContinueWith => 'VEYA ŞUNLARLA DEVAM EDİN';

  @override
  String get continueWithGoogle => 'Google';

  @override
  String get continueWithApple => 'Apple';

  @override
  String get newToLegalHub => 'LegalHub\'te yeni misiniz?';

  @override
  String get createAccount => 'Hesap oluşturun';

  @override
  String get encryptedConnectionNotice => '256-BİT ŞİFRELİ BAĞLANTI';

  @override
  String get signUpTitle => 'Hesap Oluştur';

  @override
  String get signUpSubtitle =>
      'Pratiğinizi kaydetmek için bilgilerinizi girin.';

  @override
  String get fullNameLabel => 'Ad Soyad';

  @override
  String get fullNamePlaceholder => 'Jane Doe';

  @override
  String get phoneLabel => 'Telefon Numarası';

  @override
  String get phonePlaceholder => '+1 (555) 000-0000';

  @override
  String get passwordHint => 'En az 8 karakter olmalıdır.';

  @override
  String get agreeToTerms =>
      'Kullanım Koşulları ve Gizlilik Politikası\'nı kabul ediyorum.';

  @override
  String get signUpButton => 'Hesap Oluştur';

  @override
  String get alreadyHaveAccount => 'Zaten hesabınız var mı?';

  @override
  String get signInLink => 'Giriş Yap';

  @override
  String get recoverPasswordTitle => 'Parola Kurtarma';

  @override
  String get recoverPasswordBody =>
      'Doğrulama kodu almak için kayıtlı e-posta adresinizi girin.';

  @override
  String get sendCodeButton => 'Kod Gönder';

  @override
  String get backToSignIn => 'Girişe Dön';

  @override
  String get codeSentNotice => 'Doğrulama kodu gelen kutunuza gönderildi.';

  @override
  String get verifyEmailTitle => 'E-postayı Doğrula';

  @override
  String get verifyEmailBody =>
      'E-posta adresinize 6 haneli bir kod gönderdik.';

  @override
  String get verifyAndContinueButton => 'Doğrula ve Devam Et';

  @override
  String get resendCode => 'Kodu Yeniden Gönder';

  @override
  String get resendCodeUnavailable =>
      'Kodu Yeniden Gönder (demoda kullanılamıyor)';

  @override
  String get resendHelp =>
      'E-posta gelmedi mi? Spam klasörünüzü kontrol edin veya destekle iletişime geçin.';

  @override
  String get resetPasswordTitle => 'Parolayı Sıfırla';

  @override
  String get newPasswordLabel => 'Yeni Parola';

  @override
  String get confirmPasswordLabel => 'Parolayı Onayla';

  @override
  String get resetPasswordButton => 'Parolayı Sıfırla';

  @override
  String get resetSuccessNotice =>
      'Parolanız sıfırlandı. Artık giriş yapabilirsiniz.';

  @override
  String get onboardingTitle1 => 'Uzman Hukuki Danışmanlık';

  @override
  String get onboardingDesc1 =>
      'En üst düzey hukuk profesyonelleriyle sorunsuz bağlanın. En kritik ve karmaşık meseleleriniz için eşsiz uzmanlık.';

  @override
  String get onboardingTitle2 => 'Dava Takibi';

  @override
  String get onboardingDesc2 =>
      'Hukuki meselelerinizi kesin güncellemelerle gerçek zamanlı izleyin. Yapılandırılmış zaman çizelgesi görünümüyle her prosedür adımında bilgi sahibi olun.';

  @override
  String get onboardingTitle3 => 'Güvenli İletişim';

  @override
  String get onboardingDesc3 =>
      'En güncel şifreleme protokollerini kullanan gizli mesajlaşma. Avukat-müvekkil ayrıcalığınız dijital ortamda korunur.';

  @override
  String get onboardingContinue => 'Devam Et';

  @override
  String get onboardingGetStarted => 'Başla';

  @override
  String get skip => 'ATLA';

  @override
  String get onboardingSuccessTitle => 'Hazırsınız';

  @override
  String get onboardingSuccessBody =>
      'Güvenli hukuki çalışma istasyonunuz hazır. Başlamak için giriş yapın.';

  @override
  String get onboardingSuccessAction => 'Girişe Geç';

  @override
  String homeGreeting(String name) {
    return 'Merhaba, $name';
  }

  @override
  String get homeFallbackName => 'Misafir';

  @override
  String get homeSubtitle =>
      'Bugün hukuki ihtiyaçlarınızda size nasıl yardımcı olabiliriz?';

  @override
  String get searchPlaceholder => 'Avukat veya hukuki konu bulun...';

  @override
  String get practiceAreas => 'Uygulama Alanları';

  @override
  String get viewAll => 'TÜMÜNÜ GÖR';

  @override
  String get recentActivity => 'Son Etkinlik';

  @override
  String get areaCriminal => 'Ceza';

  @override
  String get areaCivil => 'Hukuk';

  @override
  String get areaCorporate => 'Kurumsal';

  @override
  String get areaFamily => 'Aile';

  @override
  String get activeCaseChip => 'AKTİF DAVALAR';

  @override
  String get activeCaseTime => 'Bugün, 10:00 ÖÖ';

  @override
  String get activeCaseTitle => 'H. Vance Mirası - Belediye Davası';

  @override
  String get activeCaseBody =>
      'Bölge mahkemesindeki mülkiyet sınırı anlaşmazlığına ilişkin ön ihtiyati tedbir kararı için duruşma planlandı.';

  @override
  String get activeCaseAttorney => 'Av. R. Sterling';

  @override
  String get actionRequiredTitle => 'İşlem Gerekli';

  @override
  String get actionRequiredBody => 'Vekalet sözleşmesi için imza gerekiyor.';

  @override
  String get consultationTitle => 'Görüşme';

  @override
  String get consultationBody => 'Yarın 14:00\'te video görüşmesiyle.';

  @override
  String get signInErrorNotice => 'Demo oturumu başlatılamadı.';

  @override
  String get casesNavigation => 'Davalar';

  @override
  String get messagesNavigation => 'Mesajlar';

  @override
  String get profileNavigation => 'Profil';

  @override
  String get profileNameLabel => 'Ad';

  @override
  String get profileAccountIdLabel => 'Hesap Kimliği';

  @override
  String get profileRoleLabel => 'Rol';

  @override
  String get profileExpiresLabel => 'Oturum süresi';

  @override
  String get profileSessionExpired =>
      'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
}
