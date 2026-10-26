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
  String get continueAsDemo => 'Demo oturumuyla devam et';

  @override
  String get demoSessionNotice => 'Yalnızca geliştirme amaçlı demo oturumu';

  @override
  String get sessionNoticeConfigured =>
      'Canlı oturum — veriler sunucudan gelir.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get languageLabel => 'Dil';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeModeSystem => 'Sistem varsayılanı';

  @override
  String get themeModeLight => 'Açık';

  @override
  String get themeModeDark => 'Koyu';

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
  String get stateError => 'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get stateOffline => 'Çevrimdışı';

  @override
  String get stateUnauthorized => 'Erişim kullanılamıyor';

  @override
  String get stateLoading => 'Yükleniyor';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get signOut => 'Demo oturumunu sonlandır';

  @override
  String get signOutConfigured => 'Çıkış yap';

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
  String get socialSignInUnavailable =>
      'Sosyal medya ile giriş henüz kullanılamıyor. E-postayı veya demo oturumunu kullanın.';

  @override
  String get newToLegalHub => 'LegalHub\'te yeni misiniz?';

  @override
  String get createAccount => 'Hesap oluşturun';

  @override
  String get signUpErrorEmailInUse => 'Bu e-posta ile zaten bir hesap mevcut.';

  @override
  String get signUpErrorRateLimited =>
      'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get signUpErrorServiceUnavailable =>
      'Kayıt hizmeti şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';

  @override
  String get signUpErrorGeneric =>
      'Kayıt başarısız oldu. Lütfen tekrar deneyin.';

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
  String get passwordHint =>
      'En az 12 karakter ve 4\'ten 3\'ü: büyük harf, küçük harf, rakam, sembol.';

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
  String get recoveryErrorNotice =>
      'Bu istek tamamlanamadı. Lütfen tekrar deneyin.';

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
  String get otpIncompleteHint => 'Devam etmek için 6 haneli kodu girin.';

  @override
  String get notifTypeInvoiceStatus => 'Fatura oluşturuldu';

  @override
  String get notifTypeMatterUpdated => 'Dosya güncellendi';

  @override
  String get notifTypeAppointmentReminder => 'Randevu hatırlatması';

  @override
  String get notifTypeMessageReceived => 'Yeni mesaj alındı';

  @override
  String get notifTypeSystemMaintenance => 'Sistem bakımı';

  @override
  String get notifSummaryInvoiceStatus => 'Demo bildirim — fatura oluşturuldu';

  @override
  String get notifSummaryMatterUpdated =>
      'Demo bildirim — dosya durumu güncellendi';

  @override
  String get notifSummaryAppointmentReminder =>
      'Demo bildirim — danışmanlık hatırlatıcısı';

  @override
  String get notifSummaryMessageReceived =>
      'Demo bildirim — konuşmada yeni mesaj';

  @override
  String get notifSummarySystemMaintenance => 'Demo bildirim — planlı bakım';

  @override
  String get demoMatterTitle1 => 'Demo satın alma incelemesi';

  @override
  String get demoMatterTitle2 => 'Ticari kira danışmanlığı';

  @override
  String get demoMatterTitle3 => 'Usul inceleme dosyası';

  @override
  String get demoMatterTitle4 => 'Aile hukuku danışmanlığı';

  @override
  String get demoMatterTitle5 => 'Girişim kuruluş danışmanlığı';

  @override
  String get demoAttorneyBio1 => 'Şirket işlemleri ve yönetişim danışmanı.';

  @override
  String get demoAttorneyBio2 => 'Medeni davalar ve sözleşmeler.';

  @override
  String get demoAttorneyBio3 => 'Ceza savunması ve usul.';

  @override
  String get demoAttorneyBio4 => 'Aile hukuku ve kişisel durum davaları.';

  @override
  String get demoAttorneyBio5 => 'Girişim kuruluşu ve danışmanlık çalışmaları.';

  @override
  String get demoThreadTitle1 => 'Demo dosya güncellemeleri';

  @override
  String get demoThreadTitle2 => 'Danışmanlık takibi — demo';

  @override
  String get demoThreadTitle3 => 'Demo usul notları';

  @override
  String get demoThreadTitle4 => 'Aile dosyası konuşması — demo';

  @override
  String get demoThreadTitle5 => 'Girişim danışmanlığı — demo';

  @override
  String demoMessageBody(int count) {
    return 'Demo mesaj $count — genel demo içeriği, gerçek müvekkil veya hukuk verisi yok.';
  }

  @override
  String get demoAuthorAttorney => 'Demo avukat';

  @override
  String get demoAuthorClient => 'Demo müvekkil';

  @override
  String get demoDocumentTitle1 => 'Demo iş kabul mektubu';

  @override
  String get demoDocumentTitle2 => 'Örnek dosya özeti — demo';

  @override
  String get demoDocumentTitle3 => 'Demo delil dizini';

  @override
  String get demoDocumentTitle4 => 'Yazışma kaydı — demo';

  @override
  String get demoDocumentTitle5 => 'Demo uzlaşma taslağı';

  @override
  String get demoFileName1 => 'Demo vekaletname taraması';

  @override
  String get demoFileName2 => 'Demo kira eki';

  @override
  String get demoFileName3 => 'Demo delil kaydı';

  @override
  String get demoFileName4 => 'Demo yazışma kopyası';

  @override
  String get demoFileName5 => 'Demo kuruluş kontrol listesi';

  @override
  String get demoAlertTitle1 => 'Demo: bekleyen davetleri incele';

  @override
  String get demoAlertTitle2 => 'Demo: veri erişim incelemesi gerekli';

  @override
  String get demoAlertTitle3 => 'Demo: örnek uyarı — yüksek trafik';

  @override
  String get demoAlertTitle4 => 'Demo: saklama süresi doluyor';

  @override
  String get demoAlertTitle5 => 'Demo: inceleme tamamlandı';

  @override
  String get demoTaskTitle1 => 'Demo: yanıt taslağı kontrol listesi';

  @override
  String get demoTaskTitle2 => 'Demo: belgeleri topla';

  @override
  String get demoTaskTitle3 => 'Demo: müvekkil notlarını incele';

  @override
  String get demoTaskTitle4 => 'Demo: takip planla';

  @override
  String get demoTaskTitle5 => 'Demo: dosya zaman çizelgesini güncelle';

  @override
  String researchHeadline(String title) {
    return 'Araştırma notu — $title';
  }

  @override
  String researchSummaryDoc(String title, String ref) {
    return 'Sentetik derlem satırı \"$title\" ($ref) temel alınarak derlenen demo araştırma notu. Bu, demo derlemi için üretilmiş statik demo metindir — hukuki analiz değildir.';
  }

  @override
  String researchSummaryMatter(String title, String area) {
    return 'Sentetik derlem satırı \"$title\" ($area) temel alınarak derlenen demo araştırma notu. Bu, demo derlemi için üretilmiş statik demo metindir — hukuki analiz değildir.';
  }

  @override
  String researchExcerptDoc(String type, String ref) {
    return 'Derlem alıntısı: $type meta veri satırı, dosya ref \"$ref\".';
  }

  @override
  String researchExcerptMatter(String area) {
    return 'Derlem alıntısı: dosya satırı, alan \"$area\".';
  }

  @override
  String get researchRelatedMatter => 'ilgili demo dosya';

  @override
  String get resendCode => 'Kodu Yeniden Gönder';

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
  String get signInErrorNotice =>
      'Oturum açılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';

  @override
  String get validatorRequired => 'Bu alan zorunludur.';

  @override
  String get validatorEmailInvalid => 'Geçerli bir e-posta adresi girin.';

  @override
  String validatorMinLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En az $count karakter olmalıdır.',
      one: 'En az 1 karakter olmalıdır.',
    );
    return '$_temp0';
  }

  @override
  String get validatorMismatch => 'Şifreler eşleşmiyor.';

  @override
  String validatorPasswordLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En az $count karakter olmalıdır.',
      one: 'En az 1 karakter olmalıdır.',
    );
    return '$_temp0';
  }

  @override
  String get validatorPasswordClasses =>
      '4\'ten en az 3\'ünü içermelidir: büyük harf, küçük harf, rakam, sembol.';

  @override
  String get validatorPasswordEmail =>
      'Şifreniz e-posta adresinizi içermemelidir.';

  @override
  String get passwordStrengthWeak => 'Zayıf';

  @override
  String get passwordStrengthFair => 'Orta';

  @override
  String get passwordStrengthStrong => 'Güçlü';

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
  String get deleteAccountAction => 'Hesabı sil';

  @override
  String get deleteAccountConfirmTitle => 'Hesabınız silinsin mi?';

  @override
  String get deleteAccountConfirmBody =>
      'Bu işlem hesabınızı kalıcı olarak siler ve sizi tüm kuruluşlardan kaldırır. Geri alınamaz.';

  @override
  String get deleteAccountAuditNote =>
      'Verileriniz silinir; etkinliğinize ilişkin denetim kayıtları saklanır.';

  @override
  String get deleteAccountConfirmAction => 'Sil';

  @override
  String get profileSessionExpired =>
      'Oturum süresi doldu. Lütfen tekrar giriş yapın.';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get notificationsNote =>
      'Tercihler bu cihazda saklanır. Bildirim teslimi daha sonraki bir sürümde planlanmıştır.';

  @override
  String get notifAppointmentReminders => 'Randevu hatırlatmaları';

  @override
  String get notifActivityUpdates => 'Etkinlik güncellemeleri';

  @override
  String get notifSystemAlerts => 'Sistem uyarıları';

  @override
  String get cancel => 'İptal';

  @override
  String get orgTitle => 'Kuruluş';

  @override
  String get createOrgTitle => 'Kuruluş Oluştur';

  @override
  String get createOrgSubtitle =>
      'Firmanıza bir ad verin. İlk ortağı siz olacaksınız.';

  @override
  String get orgNameLabel => 'Kuruluş adı';

  @override
  String get orgNamePlaceholder => 'ör. Sterling & Associates';

  @override
  String get createOrgButton => 'Kuruluş Oluştur';

  @override
  String get rosterTitle => 'Üyeler';

  @override
  String get rosterEmpty => 'Henüz üye yok.';

  @override
  String get orgSwitcherLabel => 'Kuruluş';

  @override
  String get acceptInvitationTitle => 'Daveti kabul et';

  @override
  String get acceptInvitationBody =>
      'Ortakınızın sizinle paylaştığı tek kullanımlık kodu yapıştırın.';

  @override
  String get acceptInvitationAction => 'Kabul et';

  @override
  String get invitationAccepted => 'Davet kabul edildi.';

  @override
  String get invitationAcceptedBody => 'Kuruluşa katıldınız.';

  @override
  String get done => 'Bitti';

  @override
  String get inviteMember => 'Üye Davet Et';

  @override
  String get inviteEmailLabel => 'E-posta ile davet et';

  @override
  String get inviteRoleLabel => 'Rol ata';

  @override
  String get inviteTokenLabel => 'Tek kullanımlık kod';

  @override
  String get inviteSendButton => 'Davetiye Gönder';

  @override
  String inviteTokenBody(String email) {
    return 'Bu tek kullanımlık kodu $email ile paylaşın. Bir daha gösterilemez.';
  }

  @override
  String get inviteTokenCopy => 'Kodu kopyala';

  @override
  String get inviteTokenCopied => 'Kod panoya kopyalandı.';

  @override
  String get inviteShareLink => 'Davet bağlantısını kopyala';

  @override
  String get inviteShareLinkCopied => 'Davet bağlantısı panoya kopyalandı.';

  @override
  String get actionResendInvitation => 'Daveti yeniden gönder';

  @override
  String get actionRevokeInvitation => 'Daveti iptal et';

  @override
  String get invitationRevoked => 'Davet iptal edildi.';

  @override
  String inviteTokenResentBody(String email) {
    return '$email için yeni bir tek kullanımlık kod. Bir daha gösterilemez.';
  }

  @override
  String get memberStatusInvited => 'DAVETLİ';

  @override
  String get memberStatusActive => 'AKTİF';

  @override
  String get memberStatusSuspended => 'ASKIDA';

  @override
  String get memberStatusRemoved => 'KALDIRILDI';

  @override
  String get actionSuspend => 'Askıya al';

  @override
  String get actionReactivate => 'Yeniden etkinleştir';

  @override
  String get actionRemove => 'Kaldır';

  @override
  String get removeMemberConfirmTitle => 'Üye kaldırılsın mı?';

  @override
  String removeMemberConfirmBody(String name) {
    return '$name bu kuruluştan kaldırılsın mı?';
  }

  @override
  String get removeMemberConfirmAction => 'Kaldır';

  @override
  String get platformAdminTitle => 'Platform yöneticisi';

  @override
  String get platformAdminOrganizations => 'Kuruluşlar';

  @override
  String get platformAdminMembers => 'Üyeler';

  @override
  String get platformAdminDeleteDemo => 'Demo hesabını sil';

  @override
  String get platformAdminDeleteConfirmTitle => 'Demo hesabı silinsin mi?';

  @override
  String platformAdminDeleteConfirmBody(String name) {
    return '$name için demo hesabı silinsin mi? Bu geri alınamaz.';
  }

  @override
  String get platformAdminDeleteConfirmAction => 'Sil';

  @override
  String get platformAdminAudit => 'Denetim günlüğü';

  @override
  String get platformAdminAuditPlatform => 'Platform etkinliği';

  @override
  String get orgErrorDenied => 'Bu işlemi yapma izniniz yok.';

  @override
  String get orgErrorDuplicateMember => 'Bu kişi zaten kuruluşun bir üyesi.';

  @override
  String get orgErrorLastPartner =>
      'Kuruluşun en az bir aktif ortağı olmalıdır.';

  @override
  String get orgErrorInvalidRole => 'Bu rol atanamaz.';

  @override
  String get orgErrorInvalidName => 'Kuruluş adı boş olamaz.';

  @override
  String get orgErrorInvalidInvitation =>
      'Davetiye geçersiz veya süresi dolmuş.';

  @override
  String get orgErrorProviderUnavailable =>
      'Hizmet şu anda kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get orgErrorUnknown => 'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get actionInProgress => 'Zaten devam eden bir işlem var.';

  @override
  String get signUpCheckInboxTitle => 'Gelen Kutunuzu Kontrol Edin';

  @override
  String get signUpCheckInboxBody =>
      'E-posta adresinize bir doğrulama bağlantısı gönderdik. Hesabınızı etkinleştirmek için bağlantıyı açın, ardından giriş yapın.';

  @override
  String get signUpCheckInboxAction => 'Girişe Geç';

  @override
  String get bookingTitle => 'Danışma Rezervasyonu';

  @override
  String get bookingLocalOnlyNote =>
      'Demo modu — hiçbir danışma fiilen rezerve edilmez veya gönderilmez.';

  @override
  String get bookingNoPaymentNote => 'Bu adımda herhangi bir ödeme alınmaz.';

  @override
  String get bookingCategoryStepTitle => 'Danışma türü';

  @override
  String get bookingCategoryGeneral => 'Genel';

  @override
  String get bookingCategoryFollowUp => 'Takip';

  @override
  String get bookingCategoryUrgent => 'Acil';

  @override
  String get bookingTopicLabel => 'Konu (isteğe bağlı)';

  @override
  String get bookingTopicPlaceholder => 'Sorunuzu kısaca açıklayın';

  @override
  String get bookingContinue => 'Devam';

  @override
  String get bookingSelectDateTimeStep => 'Tarih ve saat seçin';

  @override
  String get bookingSlotsEmpty => 'Uygun zaman yok.';

  @override
  String get bookingSlotsError => 'Uygun zamanlar yüklenemedi.';

  @override
  String bookingDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes dk',
      one: '1 dk',
    );
    return '$_temp0';
  }

  @override
  String get bookingReviewStep => 'Rezervasyonunuzu gözden geçirin';

  @override
  String get bookingSummaryType => 'Tür';

  @override
  String get bookingSummaryTopic => 'Konu';

  @override
  String get bookingSummaryTime => 'Zaman';

  @override
  String get bookingSummaryNotSet => 'Belirtilmedi';

  @override
  String get bookingEditCategory => 'Türü düzenle';

  @override
  String get bookingConfirm => 'Rezervasyonu onayla';

  @override
  String get bookingConfirmFailed => 'Onaylanamadı. Lütfen tekrar deneyin.';

  @override
  String get bookingSlotUnavailable =>
      'Bu saat artık müsait değil. Başka bir saat seçin.';

  @override
  String get bookingChooseAnotherTime => 'Başka bir saat seç';

  @override
  String get bookingSuccessTitle => 'Rezervasyon onaylandı';

  @override
  String bookingSuccessBody(String referenceId) {
    return 'Referans: $referenceId';
  }

  @override
  String get bookingDone => 'Bitti';

  @override
  String get bookingEntryTitle => 'Danışma rezervasyonu';

  @override
  String get bookingEntrySubtitle =>
      'Bir danışma planlayın — geliştirme demosu.';

  @override
  String get bookingEntrySubtitleConfigured =>
      'Müsait bir avukatla danışma randevusu oluşturun.';

  @override
  String get discoveryTitle => 'Avukat Bul';

  @override
  String get discoverySearchHint => 'İsme veya uygulama alanına göre ara';

  @override
  String get discoveryFilterAll => 'Tümü';

  @override
  String get discoveryEmpty => 'Aramanızla eşleşen avukat yok.';

  @override
  String get discoveryError => 'Avukatlar yüklenemedi.';

  @override
  String get discoveryLocalOnlyNote =>
      'Demo modu — yalnızca sentetik profiller. Gerçek avukatlar listelenmez veya iletişime geçilmez.';

  @override
  String get discoveryEntryTitle => 'Bir avukat bul';

  @override
  String get discoveryEntrySubtitle =>
      'Demo avukat profillerine göz atın — geliştirme demosu.';

  @override
  String get bookingSummaryAttorney => 'Avukat';

  @override
  String bookingAttorneyPrefill(String name) {
    return '$name ile rezervasyon';
  }

  @override
  String get discoveryProfileTitle => 'Avukat profili';

  @override
  String get discoveryProfileNotFound => 'Avukat bulunamadı.';

  @override
  String get discoveryProfileBio => 'Hakkında';

  @override
  String get discoveryProfileBook => 'Bu avukatla rezervasyon yap';

  @override
  String get discoveryDirectoryNote =>
      'Dizin profilleri platform yöneticisi tarafından yönetilir. Kimlik bilgisi doğrulaması yapılmaz.';

  @override
  String get discoveryProfileSpecialties => 'Uzmanlık alanları';

  @override
  String get discoveryProfileLanguages => 'Diller';

  @override
  String discoveryProfileYears(int years) {
    return '$years yıl deneyim';
  }

  @override
  String get attorneyStatusActive => 'Etkin';

  @override
  String get attorneyStatusInactive => 'Etkin değil';

  @override
  String get attorneyAdminTitle => 'Avukat dizini';

  @override
  String get attorneyAdminEntryTitle => 'Avukat dizini';

  @override
  String get attorneyAdminEntrySubtitle =>
      'Dizin profillerini inceleyin ve yönetin.';

  @override
  String get attorneyAdminCreate => 'Avukat ekle';

  @override
  String get attorneyAdminEditTitle => 'Avukatı düzenle';

  @override
  String get attorneyAdminSave => 'Kaydet';

  @override
  String get attorneyAdminDeactivate => 'Devre dışı bırak';

  @override
  String get attorneyAdminDeactivateTitle => 'Avukat devre dışı bırakılsın mı?';

  @override
  String attorneyAdminDeactivateBody(String name) {
    return '$name devre dışı bırakılsın mı? Profil yönetici listesinde kalır ancak genel dizinden çıkar.';
  }

  @override
  String get attorneyAdminDeactivateFailed =>
      'Profil devre dışı bırakılamadı. Lütfen tekrar deneyin.';

  @override
  String get attorneyAdminEmpty => 'Henüz avukat profili yok.';

  @override
  String get attorneyAdminError => 'Avukat profilleri yüklenemedi.';

  @override
  String get attorneyAdminNote =>
      'Profiller platform yöneticisi tarafından yönetilir. Kimlik bilgisi doğrulaması yapılmaz.';

  @override
  String get attorneyAdminNameLabel => 'Görünen ad';

  @override
  String get attorneyAdminHeadlineLabel => 'Başlık (isteğe bağlı)';

  @override
  String get attorneyAdminBioLabel => 'Biyografi (isteğe bağlı)';

  @override
  String get attorneyAdminSpecialtiesLabel => 'Uzmanlık alanları';

  @override
  String get attorneyAdminLanguagesLabel => 'Diller (isteğe bağlı)';

  @override
  String get attorneyAdminLanguagesHint => 'Virgülle ayırın, ör. EN, AR';

  @override
  String get attorneyAdminCityLabel => 'Şehir (isteğe bağlı)';

  @override
  String get attorneyAdminYearsLabel => 'Deneyim yılı (isteğe bağlı)';

  @override
  String get attorneyAdminNameRequired => 'Görünen adı girin.';

  @override
  String get attorneyAdminNameTooShort => 'En az 2 karakter girin.';

  @override
  String get attorneyAdminYearsInvalid =>
      '0 ile 80 arasında bir tam sayı girin.';

  @override
  String get attorneyAdminSpecialtyRequired =>
      'En az bir uzmanlık alanı seçin.';

  @override
  String get attorneyAdminSaveFailed =>
      'Profil kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get matterTitle => 'Davalar';

  @override
  String get matterFilterAll => 'Tümü';

  @override
  String get matterStatusOpen => 'Açık';

  @override
  String get matterStatusActive => 'Aktif';

  @override
  String get matterStatusClosed => 'Kapalı';

  @override
  String get matterEmpty => 'Filtreyle eşleşen dava yok.';

  @override
  String get matterError => 'Davalar yüklenemedi.';

  @override
  String get matterLocalOnlyNote =>
      'Demo modu — yalnızca sentetik davalar. Gerçek davalar listelenmez.';

  @override
  String get matterEntryTitle => 'Davalarım';

  @override
  String get matterEntrySubtitle =>
      'Demo dava dosyalarına göz atın — geliştirme demosu.';

  @override
  String get matterEntrySubtitleConfigured =>
      'Kendi davalarınıza ve dosyalarına göz atın.';

  @override
  String get matterDetailsTitle => 'Dava detayları';

  @override
  String get matterDetailsNotFound => 'Dava bulunamadı.';

  @override
  String get matterDetailsPracticeArea => 'Çalışma alanı';

  @override
  String get matterDetailsAssignedAttorney => 'Atanan avukat';

  @override
  String get matterDetailsCreated => 'Oluşturulma';

  @override
  String get matterCreateFab => 'Yeni dava';

  @override
  String get matterCreateTitle => 'Dava oluştur';

  @override
  String get matterCreateTitleLabel => 'Başlık';

  @override
  String get matterCreateTitleHint =>
      'Genel demo ifadesi — gerçek bir müvekkil veya dava adı değil';

  @override
  String get matterCreatePracticeAreaLabel => 'Çalışma alanı';

  @override
  String get matterCreateAssignedClientLabel =>
      'Atanan müvekkil (isteğe bağlı)';

  @override
  String get matterCreateAssignedAttorneyLabel =>
      'Atanan avukat (isteğe bağlı)';

  @override
  String get matterCreateAssigneeNone => 'Yok';

  @override
  String get matterCreateNoOrg =>
      'Etkin bir kuruluş seçilmedi. Kuruluş merkezinden bir kuruluş seçin, ardından dava oluşturmak için buraya dönün.';

  @override
  String get matterCreateSubmit => 'Dava oluştur';

  @override
  String get matterCreateSuccessTitle => 'Dava oluşturuldu';

  @override
  String matterCreateSuccessBody(String id) {
    return '$id numaralı dava oluşturuldu.';
  }

  @override
  String get matterCreateSuccessNote =>
      'Siz oluşturduğunuz için şimdi görüyorsunuz. Onlara atandığında diğerleri de görür.';

  @override
  String get matterCreateDone => 'Tamam';

  @override
  String get matterCreateErrorDenied =>
      'Bu kuruluşta dava oluşturma izniniz yok.';

  @override
  String get matterCreateErrorOwnerForbidden =>
      'Platform sahibi bir davaya atanamaz.';

  @override
  String get matterCreateErrorAssigneeInvalid =>
      'Atanan üye bu kuruluşun aktif bir üyesi değil.';

  @override
  String get matterCreateErrorValidation => 'Dava başlığı gereklidir.';

  @override
  String get matterCreateErrorUnavailable =>
      'Dava oluşturma geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get matterCreateErrorFailed =>
      'Dava oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get vaultTitle => 'Belgeler';

  @override
  String get vaultEmpty => 'Kullanılabilir belge yok.';

  @override
  String get vaultError => 'Belgeler yüklenemedi.';

  @override
  String get vaultLocalOnlyNote =>
      'Demo modu — yalnızca sentetik belge meta verileri. Gerçek dosyalar listelenmez.';

  @override
  String get viewMatter => 'Davayı görüntüle';

  @override
  String get vaultEntryTitle => 'Belge kasası';

  @override
  String get vaultEntrySubtitle =>
      'Demo belge meta verilerine göz atın — geliştirme demosu.';

  @override
  String get vaultEntrySubtitleConfigured =>
      'Dosyalarınıza eklenen belgeleri görüntüleyin.';

  @override
  String get documentTypeContract => 'Sözleşme';

  @override
  String get documentTypeBrief => 'Özet';

  @override
  String get documentTypeEvidence => 'Kanıt';

  @override
  String get documentTypeCorrespondence => 'Yazışma';

  @override
  String get messagesTitle => 'Mesajlar';

  @override
  String get messagesEmpty => 'Kullanılabilir mesaj dizisi yok.';

  @override
  String get messagesError => 'Mesaj dizileri yüklenemedi.';

  @override
  String get messagesLocalOnlyNote =>
      'Demo modu — yalnızca sentetik dizgi meta verileri. Gerçek mesajlar listelenmez.';

  @override
  String get messagesEntryTitle => 'Mesajlar';

  @override
  String get messagesEntrySubtitle =>
      'Demo mesaj dizilerine göz atın — geliştirme demosu.';

  @override
  String get messagesEntrySubtitleConfigured =>
      'Kendi mesaj dizilerinize göz atın.';

  @override
  String messagesMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaj',
      one: '1 mesaj',
      zero: 'Mesaj yok',
    );
    return '$_temp0';
  }

  @override
  String get messageThreadDetailTitle => 'Konu mesajları';

  @override
  String get messagesDetailEmpty => 'Bu konuşmada kullanılabilir mesaj yok.';

  @override
  String get messagesDetailError => 'Mesajlar yüklenemedi.';

  @override
  String get messageComposerHint => 'Bir mesaj yazın';

  @override
  String get messageSend => 'Gönder';

  @override
  String messageErrorTooLong(int max) {
    return 'Mesaj çok uzun. En fazla $max karakter olabilir.';
  }

  @override
  String get messageErrorDenied => 'Bu konuşmada mesaj gönderme izniniz yok.';

  @override
  String get messageErrorUnavailable =>
      'Gönderme geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get messageErrorFailed =>
      'Mesaj gönderilemedi. Lütfen tekrar deneyin.';

  @override
  String get searchTitle => 'Ara';

  @override
  String get searchNoQuery =>
      'Demo konular, belgeler, mesajlar veya avukatlar bulmak için bir arama terimi yazın.';

  @override
  String get searchEmpty => 'Aramanızla eşleşen sonuç yok.';

  @override
  String get searchError => 'Arama çalıştırılamadı.';

  @override
  String get searchPartialUnavailable =>
      'Bazı kaynaklara ulaşılamadı — sonuçlar eksik olabilir.';

  @override
  String get searchLocalOnlyNote =>
      'Demo modu — sonuçlar yalnızca sentetik listelerden gelir. Gerçek veri aranmaz.';

  @override
  String get matterWorkspaceDocumentsTitle => 'Belgeler';

  @override
  String get matterWorkspaceDocumentsEmpty =>
      'Bu dava için kullanılabilir belge yok.';

  @override
  String get matterWorkspaceMessagesTitle => 'Mesajlar';

  @override
  String get matterWorkspaceMessagesEmpty =>
      'Bu dava için kullanılabilir mesaj dizisi yok.';

  @override
  String get matterWorkspaceFilesTitle => 'Dosyalar';

  @override
  String get matterWorkspaceFilesEmpty =>
      'Bu dava için kullanılabilir dosya yok.';

  @override
  String get filesError => 'Dosyalar yüklenemedi.';

  @override
  String get fileUploadAction => 'Dosya yükle';

  @override
  String fileUploading(String fileName) {
    return '$fileName yükleniyor…';
  }

  @override
  String get fileUploadSuccess => 'Dosya yüklendi.';

  @override
  String get fileUploadFailed => 'Dosya yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get fileUploadTooLarge =>
      'Bu dosya çok büyük. En fazla 25 MB olabilir.';

  @override
  String get fileUploadUnsupportedType => 'Bu dosya türü desteklenmiyor.';

  @override
  String get fileUploadDenied => 'Bu davaya dosya yükleme izniniz yok.';

  @override
  String get fileOpenAction => 'Aç';

  @override
  String get fileOpenFailed => 'Dosya açılamadı. Lütfen tekrar deneyin.';

  @override
  String fileSizeMb(String value) {
    return '$value MB';
  }

  @override
  String fileSizeKb(String value) {
    return '$value KB';
  }

  @override
  String fileSizeBytes(String value) {
    return '$value B';
  }

  @override
  String get matterWorkspaceInvoicesTitle => 'Faturalar';

  @override
  String get matterWorkspaceInvoicesEmpty =>
      'Bu dava için kullanılabilir fatura yok.';

  @override
  String get invoicesTitle => 'Faturalar';

  @override
  String get invoicesEmpty => 'Kullanılabilir fatura yok.';

  @override
  String get invoicesError => 'Faturalar yüklenemedi.';

  @override
  String get invoicesLocalOnlyNote =>
      'Demo modu — yalnızca sentetik fatura meta verileri. Gerçek ödeme almaz.';

  @override
  String get invoicesEntryTitle => 'Faturalama';

  @override
  String get invoicesEntrySubtitle =>
      'Sentetik fatura meta verilerine göz atın — geliştirme demosu.';

  @override
  String get invoicesEntrySubtitleConfigured =>
      'Faturaları ve ödeme durumlarını görüntüleyin.';

  @override
  String get invoiceStatusIssued => 'Düzenlendi';

  @override
  String get invoiceStatusPaid => 'Ödendi';

  @override
  String get invoicePayAction => 'Öde';

  @override
  String get paymentSheetTitle => 'Fatura ödemesi';

  @override
  String get paymentPreparing => 'Güvenli ödeme hazırlanıyor…';

  @override
  String get paymentWaiting => 'Ödeme onayı bekleniyor…';

  @override
  String get paymentSuccessTitle => 'Ödeme başarılı';

  @override
  String get paymentSuccessBody =>
      'Ödemeniz onaylandı. Fatura ödendi olarak işaretlenecek.';

  @override
  String get paymentDemoSuccessBody =>
      'Demo ödeme simüle edildi — ücret alınmadı ve fatura değişmedi.';

  @override
  String get paymentFailedTitle => 'Ödeme başarısız';

  @override
  String get paymentFailedBody =>
      'Ödeme tamamlanamadı. Tekrar deneyebilirsiniz.';

  @override
  String get paymentCancelledTitle => 'Ödeme iptal edildi';

  @override
  String get paymentCancelledBody =>
      'Ödeme iptal edildi. Tekrar deneyebilirsiniz.';

  @override
  String get paymentExpiredTitle => 'Ödemenin süresi doldu';

  @override
  String get paymentExpiredBody =>
      'Ödeme oturumunun süresi doldu. Yeni bir ödeme başlatabilirsiniz.';

  @override
  String get paymentCheckStatus => 'Durumu kontrol et';

  @override
  String get paymentRetry => 'Tekrar dene';

  @override
  String get paymentClose => 'Kapat';

  @override
  String get paymentOpenCheckout => 'Ödeme sayfasını aç';

  @override
  String get paymentUnavailable =>
      'Ödemeler şu anda kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get paymentDemoNote => 'Yalnızca demo — gerçek ücret alınmaz.';

  @override
  String get paymentHostedCheckoutNote =>
      'Ödemeyi güvenli barındırılan ödeme sayfasında tamamlayın, ardından bu ekrana dönün.';

  @override
  String get paymentDemoSuccess => 'Başarıyı simüle et';

  @override
  String get paymentDemoFailure => 'Başarısızlığı simüle et';

  @override
  String get paymentDemoCancel => 'İptali simüle et';

  @override
  String get orgAuditTitle => 'Denetim kaydı';

  @override
  String get orgAuditEmpty => 'Henüz hiçbir denetim olayı kaydedilmedi.';

  @override
  String get orgAuditNoOrganization => 'Kuruluş seçilmedi.';

  @override
  String get orgAuditDenied =>
      'Bu kuruluşun denetim kaydını görüntüleme izniniz yok.';

  @override
  String get orgAuditError => 'Denetim kaydı yüklenemedi.';

  @override
  String get orgAuditRetry => 'Tekrar dene';

  @override
  String get orgAuditHubEntry => 'Denetim kaydını görüntüle';

  @override
  String get orgAuditOutcomeAllowed => 'İzinli';

  @override
  String get orgAuditOutcomeDenied => 'Reddedildi';

  @override
  String get alertsTitle => 'Uyum uyarıları';

  @override
  String get alertsError => 'Uyum uyarıları yüklenemedi.';

  @override
  String get alertsLocalOnlyNote =>
      'Demo modu — yalnızca sentetik uyarılar. Gerçek bir uyum olayı gösterilmez.';

  @override
  String get alertsEntryTitle => 'Uyum uyarıları';

  @override
  String get alertsEntrySubtitle =>
      'Sentetik uyarılara göz atın — geliştirme demosu.';

  @override
  String get alertsEntrySubtitleConfigured =>
      'Kuruluş uyum uyarılarını inceleyin.';

  @override
  String get alertsStoredNote =>
      'Uyarılar bu kuruluş için kaydedilir. Otomatik hukuki doğrulama yapılmaz.';

  @override
  String get alertsEmptyFiltered => 'Bu filtreyle eşleşen uyarı yok.';

  @override
  String get alertsFilterAll => 'Tümü';

  @override
  String get alertsCreateFab => 'Yeni uyarı';

  @override
  String get alertStatusOpen => 'Açık';

  @override
  String get alertStatusAcknowledged => 'Görüldü';

  @override
  String get alertStatusResolved => 'Çözüldü';

  @override
  String get alertKindDeadline => 'Son tarih';

  @override
  String get alertKindConflict => 'Çıkar çatışması kontrolü';

  @override
  String get alertKindRetention => 'Saklama süresi';

  @override
  String get alertKindFiling => 'Dosyalama';

  @override
  String get alertKindOther => 'Diğer';

  @override
  String get alertSeverityLow => 'Düşük';

  @override
  String get alertSeverityMedium => 'Orta';

  @override
  String get alertSeverityHigh => 'Yüksek';

  @override
  String get alertSeverityCritical => 'Kritik';

  @override
  String get alertCreateTitle => 'Yeni uyum uyarısı';

  @override
  String get alertCreateTitleLabel => 'Başlık';

  @override
  String get alertCreateTitleHint => 'örn. Dosyalama son tarihi incelemesi';

  @override
  String get alertCreateTitleTooShort => 'Başlık en az 2 karakter olmalıdır.';

  @override
  String get alertCreateTitleTooLong =>
      'Başlık 160 karakter veya daha kısa olmalıdır.';

  @override
  String get alertCreateKindLabel => 'Tür';

  @override
  String get alertCreateSeverityLabel => 'Önem';

  @override
  String get alertCreateDescriptionLabel => 'Açıklama (isteğe bağlı)';

  @override
  String get alertCreateDescriptionTooLong =>
      'Açıklama 4000 karakter veya daha kısa olmalıdır.';

  @override
  String get alertCreateSubmit => 'Uyarı oluştur';

  @override
  String get alertCreateSuccess => 'Uyarı oluşturuldu.';

  @override
  String get alertCreateNoOrg => 'Uyarı oluşturmadan önce bir kuruluş seçin.';

  @override
  String get alertDetailKind => 'Tür';

  @override
  String get alertDetailSeverity => 'Önem';

  @override
  String get alertDetailCreated => 'Oluşturuldu';

  @override
  String get alertDetailDue => 'Son tarih';

  @override
  String get alertDetailDescription => 'Açıklama';

  @override
  String get alertDetailAcknowledged => 'Görüldü';

  @override
  String get alertDetailResolved => 'Çözüldü';

  @override
  String get alertAcknowledgeAction => 'Uyarıyı görüldü olarak işaretle';

  @override
  String get alertResolveAction => 'Uyarıyı çöz';

  @override
  String get alertResolveNoteLabel => 'Not (isteğe bağlı)';

  @override
  String get alertAcknowledgedSuccess => 'Uyarı görüldü olarak işaretlendi.';

  @override
  String get alertResolvedSuccess => 'Uyarı çözüldü.';

  @override
  String get alertErrorDenied => 'Bunu yapma izniniz yok.';

  @override
  String get alertErrorUnavailable =>
      'Hizmet geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get alertErrorInvalid =>
      'Uyarı artık güncellenemiyor. Yenileyip tekrar deneyin.';

  @override
  String get alertErrorFailed =>
      'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get tasksTitle => 'Görev panosu';

  @override
  String get tasksEmpty => 'Kullanılabilir görev yok.';

  @override
  String get tasksError => 'Görevler yüklenemedi.';

  @override
  String get tasksLocalOnlyNote =>
      'Demo modu — yalnızca sentetik görevler. Gerçek dava işleri listelenmez.';

  @override
  String get tasksEntryTitle => 'Görev panosu';

  @override
  String get tasksEntrySubtitle =>
      'Sentetik görevlere göz atın — geliştirme demosu.';

  @override
  String get tasksEntrySubtitleConfigured =>
      'Size atanmış görevleri görüntüleyin.';

  @override
  String get taskStatusTodo => 'Yapılacak';

  @override
  String get taskStatusInProgress => 'Sürüyor';

  @override
  String get taskStatusBlocked => 'Engellendi';

  @override
  String get taskStatusDone => 'Tamamlandı';

  @override
  String get taskAcknowledge => 'Onayla';

  @override
  String get taskAcknowledged => 'Onaylandı';

  @override
  String get taskCreateAction => 'Yeni görev';

  @override
  String get taskCreateTitle => 'Yeni görev';

  @override
  String get taskCreateTitleLabel => 'Görev başlığı';

  @override
  String get taskCreateTitleHint => 'örn. Yanıt kontrol listesi';

  @override
  String get taskCreateMatterLabel => 'Dosya';

  @override
  String get taskCreateMatterHint => 'Bir dosya seçin';

  @override
  String get taskCreateSubmit => 'Görevi oluştur';

  @override
  String get taskCreateNoMatters => 'Görev oluşturulabilecek dosya yok.';

  @override
  String get taskCreateMattersError =>
      'Dosyalar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get taskAssignAction => 'Ata';

  @override
  String get taskAssignTitle => 'Görevi ata';

  @override
  String get taskAssignMemberLabel => 'Atanan kişi';

  @override
  String get taskAssignUnassigned => 'Atanmamış';

  @override
  String get taskAssignSubmit => 'Atamayı kaydet';

  @override
  String get taskAssignMembersError =>
      'Üyeler yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get taskAssigneeUnavailable => 'Mevcut atanan kişi kullanılamıyor';

  @override
  String get taskErrorDenied => 'Bunu yapma izniniz yok.';

  @override
  String get taskErrorUnavailable =>
      'Bu özellik geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get taskErrorInvalid =>
      'Bu değişiklik geçerli değil. Ayrıntıları kontrol edip tekrar deneyin.';

  @override
  String get taskErrorFailed => 'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get approvalsTitle => 'Bekleyen onaylar';

  @override
  String get approvalsError => 'Onaylar yüklenemedi.';

  @override
  String get approvalsLocalOnlyNote =>
      'Demo modu — yalnızca sentetik gizlenmiş satırlar. Bekleyen gerçek bir onay yok.';

  @override
  String get approvalsEntryTitle => 'Bekleyen onaylar';

  @override
  String get approvalsEntrySubtitle =>
      'Sentetik onaylara göz atın — geliştirme demosu.';

  @override
  String get approvalsEntrySubtitleConfigured =>
      'Kuruluş onay taleplerini inceleyin.';

  @override
  String get approvalStatusPending => 'Bekliyor';

  @override
  String get approvalStatusApproved => 'Onaylandı';

  @override
  String get approvalStatusDenied => 'Reddedildi';

  @override
  String get approvalStatusCancelled => 'İptal edildi';

  @override
  String get approvalsScreenTitle => 'Onaylar';

  @override
  String get approvalsStoredNote => 'Talepler bu kuruluş için saklanır.';

  @override
  String get approvalsEmptyFiltered => 'Bu filtreyle eşleşen onay yok.';

  @override
  String get approvalsFilterAll => 'Tümü';

  @override
  String get approvalsCreateFab => 'Yeni talep';

  @override
  String get approvalKindConflict => 'Çıkar çatışması kontrolü';

  @override
  String get approvalKindWaiver => 'Feragat';

  @override
  String get approvalKindFiling => 'Mahkemeye sunum';

  @override
  String get approvalKindExpense => 'Masraf';

  @override
  String get approvalKindOther => 'Diğer';

  @override
  String get approvalCreateTitle => 'Yeni onay talebi';

  @override
  String get approvalCreateTitleLabel => 'Başlık';

  @override
  String get approvalCreateTitleHint =>
      'Örn. yeni dosya için çıkar çatışması feragatı';

  @override
  String get approvalCreateTitleTooShort =>
      'Başlık en az 2 karakter olmalıdır.';

  @override
  String get approvalCreateTitleTooLong =>
      'Başlık en fazla 160 karakter olabilir.';

  @override
  String get approvalCreateKindLabel => 'Tür';

  @override
  String get approvalCreateMatterLabel => 'Dosya (isteğe bağlı)';

  @override
  String get approvalCreateMatterNone => 'Dosya yok';

  @override
  String get approvalCreateMattersError =>
      'Dosyalar yüklenemedi. Dosya olmadan da gönderebilirsiniz.';

  @override
  String get approvalCreateDescriptionLabel => 'Açıklama (isteğe bağlı)';

  @override
  String get approvalCreateDescriptionTooLong =>
      'Açıklama en fazla 4000 karakter olabilir.';

  @override
  String get approvalCreateSubmit => 'Talebi gönder';

  @override
  String get approvalCreateSuccess => 'Talep gönderildi.';

  @override
  String get approvalCreateNoOrg =>
      'Talep oluşturmadan önce bir kuruluş seçin.';

  @override
  String get approvalDetailKind => 'Tür';

  @override
  String get approvalDetailCreated => 'Oluşturuldu';

  @override
  String get approvalDetailDescription => 'Açıklama';

  @override
  String get approvalDetailDecided => 'Karar verildi';

  @override
  String get approvalDetailDecisionNote => 'Karar notu';

  @override
  String get approvalApprove => 'Onayla';

  @override
  String get approvalReject => 'Reddet';

  @override
  String get approvalDecideNoteLabel => 'Not (reddetmek için gerekli)';

  @override
  String get approvalRejectNoteRequired =>
      'Reddetmek için en az 2 karakterlik bir not ekleyin.';

  @override
  String get approvalCancelAction => 'Talebi iptal et';

  @override
  String get approvalCancelConfirmTitle => 'Bu talep iptal edilsin mi?';

  @override
  String get approvalCancelConfirmBody =>
      'Talep iptal edildi olarak işaretlenecek. Bu işlem geri alınamaz.';

  @override
  String get approvalDecidedApproved => 'Talep onaylandı.';

  @override
  String get approvalDecidedRejected => 'Talep reddedildi.';

  @override
  String get approvalCancelled => 'Talep iptal edildi.';

  @override
  String get approvalErrorDenied => 'Bunu yapma izniniz yok.';

  @override
  String get approvalErrorUnavailable =>
      'Hizmet geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get approvalErrorInvalid =>
      'Talep artık güncellenemiyor. Yenileyip tekrar deneyin.';

  @override
  String get approvalErrorFailed =>
      'Bir şeyler ters gitti. Lütfen tekrar deneyin.';

  @override
  String get notificationsFeedTitle => 'Bildirim akışı';

  @override
  String get notificationsFeedEmpty => 'Kullanılabilir bildirim yok.';

  @override
  String get notificationsFeedError => 'Bildirimler yüklenemedi.';

  @override
  String get notificationsFeedLocalOnlyNote =>
      'Demo modu — yalnızca sentetik bildirim meta verileri. Push veya teslimat gösterilmez.';

  @override
  String get notificationsFeedEntryTitle => 'Bildirim akışı';

  @override
  String get notificationsFeedEntrySubtitle =>
      'Kuruluş etkinlik uyarılarını görüntüleyin — salt okunur demo akışı.';

  @override
  String get notificationsFeedEntrySubtitleConfigured =>
      'Kuruluşunuzun etkinlik uyarılarını görüntüleyin.';

  @override
  String get notificationCategoryAppointment => 'Randevu';

  @override
  String get notificationCategoryActivity => 'Etkinlik';

  @override
  String get notificationCategorySystem => 'Sistem';

  @override
  String get aiResearchTitle => 'YZ araştırması';

  @override
  String get aiResearchAdvisoryBanner =>
      'YZ önerisi — hukuki tavsiye değildir. Yalnızca sentetik demo verileri üzerinde demo araştırma.';

  @override
  String get aiResearchFieldHint => 'Bir araştırma sorusu sorun…';

  @override
  String get aiResearchIdlePrompt =>
      'Demo araştırma derleminde arama yapmak için bir soru sorun.';

  @override
  String get aiResearchNoMatches =>
      'Demo derleminde eşleşme yok. Farklı kelimeler deneyin.';

  @override
  String get aiResearchError => 'Araştırma sorgusu çalıştırılamadı.';

  @override
  String get aiResearchLocalOnlyNote =>
      'Demo modu — yalnızca kaynaklı sentetik bulgular. Hiçbir şey saklanmaz veya gönderilmez.';

  @override
  String get aiResearchCitationsLabel => 'Kaynaklar';

  @override
  String get aiResearchEntryTitle => 'YZ araştırması';

  @override
  String get aiResearchEntrySubtitle =>
      'Demo araştırma asistanına sorun — yalnızca tavsiye niteliğinde.';

  @override
  String get notificationsFeedUnreadSemantics =>
      'Okunmamış bildirim. Okundu olarak işaretlemek için dokunun.';

  @override
  String get notificationsFeedMutedEmpty =>
      'Bildirimler bildirim ayarlarınızdan sessize alındı.';

  @override
  String get videoTitle => 'Görüntülü görüşmeler';

  @override
  String get videoEmpty => 'Henüz görüntülü görüşme yok.';

  @override
  String get videoError => 'Görüntülü görüşmeler yüklenemedi.';

  @override
  String get videoLocalOnlyNote =>
      'Demo modu — yalnızca örnek oturumlar. Görüntülü aramalar yapılandırılmış bir dağıtım gerektirir.';

  @override
  String get videoEntryTitle => 'Görüntülü görüşme';

  @override
  String get videoEntrySubtitle => 'Görüntülü görüşme planlayın veya katılın.';

  @override
  String get videoEntrySubtitleConfigured =>
      'Hukuk ekibinizle görüntülü görüşme planlayın veya katılın.';

  @override
  String get videoJoin => 'Aramaya katıl';

  @override
  String videoCallElapsed(String duration) {
    return 'Süre $duration';
  }

  @override
  String get videoCallYou => 'Siz';

  @override
  String get videoMicOn => 'Mikrofonu sessize al';

  @override
  String get videoMicMuted => 'Mikrofonun sesini aç';

  @override
  String get videoCameraOn => 'Kamerayı kapat';

  @override
  String get videoCameraOff => 'Kamerayı aç';

  @override
  String get videoLeave => 'Aramadan ayrıl';

  @override
  String get videoStoredNote =>
      'Görüntülü görüşmeler kuruluşunuzla birlikte saklanır. Aramalar LiveKit üzerinden yapılır; hiçbir şey kaydedilmez.';

  @override
  String get videoCreateFab => 'Planla';

  @override
  String get videoCreateTitle => 'Görüntülü görüşme planla';

  @override
  String get videoCreateMatterLabel => 'Dosya (isteğe bağlı)';

  @override
  String get videoCreateMatterNone => 'Dosya yok';

  @override
  String get videoCreateMattersError => 'Dosyalar yüklenemedi.';

  @override
  String get videoCreateDateLabel => 'Tarih ve saat';

  @override
  String get videoCreateDateRequired => 'Oturum için bir tarih ve saat seçin.';

  @override
  String get videoCreateNoOrg => 'Oturum planlamadan önce bir kuruluş seçin.';

  @override
  String get videoCreateSubmit => 'Oturumu planla';

  @override
  String get videoCreateSuccess => 'Görüntülü görüşme planlandı.';

  @override
  String get videoEnd => 'Bitir';

  @override
  String get videoEndConfirmTitle => 'Bu görüşme bitirilsin mi?';

  @override
  String get videoEndConfirmBody =>
      'Herkesin bağlantısı kesilecek ve oturum bitmiş olarak işaretlenecek.';

  @override
  String get videoEndConfirm => 'Oturumu bitir';

  @override
  String get videoEndSuccess => 'Görüntülü görüşme bitirildi.';

  @override
  String get videoStatusScheduled => 'Planlandı';

  @override
  String get videoStatusLive => 'Canlı';

  @override
  String get videoStatusEnded => 'Bitti';

  @override
  String get videoStatusCancelled => 'İptal edildi';

  @override
  String get videoSessionTitle => 'Görüntülü görüşme';

  @override
  String get videoProviderNotConfigured =>
      'Görüntülü aramalar bu dağıtım için yapılandırılmamış. Hiçbir arama başlatılmadı.';

  @override
  String get videoJoinUnavailableTitle => 'Arama kullanılamıyor';

  @override
  String get videoErrorUnauthorized =>
      'Görüntülü görüşmeleri kullanmak için tekrar giriş yapın.';

  @override
  String get videoErrorForbidden => 'Bunu yapma izniniz yok.';

  @override
  String get videoErrorNotFound => 'Bu görüntülü görüşme bulunamadı.';

  @override
  String get videoErrorEnded => 'Bu görüntülü görüşme zaten bitti.';

  @override
  String get videoErrorInvalid =>
      'Oturum ayrıntılarını kontrol edip tekrar deneyin.';

  @override
  String get videoErrorUnavailable =>
      'Görüntülü aramalar geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get videoErrorFailed =>
      'Bu işlem tamamlanamadı. Lütfen tekrar deneyin.';

  @override
  String get videoNoOrg =>
      'Görüntülü görüşmeleri görmek için bir kuruluş seçin.';

  @override
  String get videoCallConnecting => 'Bağlanıyor…';

  @override
  String get videoCallFailed => 'Aramaya bağlanılamadı.';

  @override
  String get videoCallMediaWarning =>
      'Bağlandı, ancak kamera veya mikrofon açılamadı.';

  @override
  String get unmatchedRouteTitle => 'Bu bağlantı açılamadı.';

  @override
  String get aiResearchQuestionLabel => 'Araştırma sorusu';

  @override
  String get aiResearchQuestionTooShort => 'En az 2 karakter girin.';

  @override
  String get aiResearchQuestionTooLong =>
      'Soruyu en fazla 500 karakterde tutun.';

  @override
  String get aiResearchMatterLabel => 'Dosya (isteğe bağlı)';

  @override
  String get aiResearchMatterNone => 'Dosya yok';

  @override
  String get aiResearchMattersError => 'Dosyalar yüklenemedi.';

  @override
  String get aiResearchDocumentsLabel => 'Belgeler (isteğe bağlı)';

  @override
  String get aiResearchDocumentsError => 'Belgeler yüklenemedi.';

  @override
  String get aiResearchDocumentsNone => 'Kullanılabilir belge yok.';

  @override
  String get aiResearchReload => 'Yeniden yükle';

  @override
  String get aiResearchGenerate => 'Bulguları oluştur';

  @override
  String get aiResearchRunsTitle => 'Son araştırma çalışmaları';

  @override
  String get aiResearchRunsEmpty => 'Henüz araştırma çalışması yok.';

  @override
  String get aiResearchRunsError => 'Çalışma geçmişi yüklenemedi.';

  @override
  String get aiResearchRunStatusRunning => 'Çalışıyor';

  @override
  String get aiResearchRunStatusCompleted => 'Tamamlandı';

  @override
  String get aiResearchRunStatusFailed => 'Başarısız';

  @override
  String get aiResearchProviderNotConfigured =>
      'Yapay zekâ araştırması bu dağıtım için yapılandırılmamış. Hiçbir analiz çalıştırılmadı.';

  @override
  String get aiResearchGeneratedNotice =>
      'Yapay zekâ tarafından oluşturuldu — güvenmeden önce inceleyin. Hukuki tavsiye değildir.';

  @override
  String get aiResearchStoredNote =>
      'Yapay zekâ bulguları kuruluşunuzla birlikte saklanır.';

  @override
  String get aiResearchIdlePromptReal =>
      'Seçili dosya ve belgeler üzerinde bir soru sorun.';

  @override
  String get aiResearchErrorUnauthorized =>
      'Yapay zekâ araştırmasını kullanmak için yeniden giriş yapın.';

  @override
  String get aiResearchErrorForbidden =>
      'Rolünüz yapay zekâ araştırması çalıştıramaz.';

  @override
  String get aiResearchErrorInvalidRequest =>
      'Soruyu ve seçilenleri kontrol edip yeniden deneyin.';

  @override
  String get aiResearchErrorContextTooLarge =>
      'Seçilen bağlam çok büyük. Belgeleri azaltıp yeniden deneyin.';

  @override
  String get aiResearchErrorProviderUnavailable =>
      'Yapay zekâ sağlayıcısı geçici olarak kullanılamıyor. Lütfen yeniden deneyin.';

  @override
  String get aiResearchErrorInvalidResponse =>
      'Yapay zekâ sağlayıcısı beklenmeyen bir yanıt döndürdü. Lütfen yeniden deneyin.';

  @override
  String get aiResearchErrorNoOrg =>
      'Araştırmayı çalıştırmak için bir kuruluş seçin.';

  @override
  String get aiResearchNoSourceCited => 'Kaynak belirtilmedi.';

  @override
  String get aiResearchSourceDocument => 'Belge';

  @override
  String get aiResearchSourceMatter => 'Dosya';

  @override
  String get demoApprovalTitleConflictNew =>
      'Demo çıkar çatışması kontrolü — yeni başvuru';

  @override
  String get demoApprovalTitleEngagementWaiver => 'Demo görev feragatnamesi';

  @override
  String get demoApprovalTitleCourtFiling => 'Demo mahkeme başvurusu onayı';

  @override
  String get demoApprovalTitleExpense => 'Demo masraf onayı';

  @override
  String get demoApprovalTitleConflictOpposing =>
      'Demo çıkar çatışması kontrolü — karşı taraf';

  @override
  String get demoApprovalDescriptionWaiver =>
      'Sentetik demo talebi — gerçek müvekkil veya dava verisi yok.';

  @override
  String get demoApprovalDecisionApproved => 'Demo kararı — onaylandı.';

  @override
  String get demoApprovalDecisionRejected => 'Demo kararı — reddedildi.';

  @override
  String get demoAlertDescriptionReview =>
      'Sentetik demo uyarısı — gerçek bir uyum olayı gösterilmez.';

  @override
  String get demoAttorneyHeadlineCorporate => 'Kurumsal ve yönetişim danışmanı';

  @override
  String get demoAttorneyHeadlineCivil => 'Medeni dava ve sözleşmeler';

  @override
  String get demoAttorneyHeadlineCriminal => 'Ceza savunması ve usul';

  @override
  String get demoAttorneyHeadlineFamily => 'Aile hukuku ve kişisel statü';

  @override
  String get demoAttorneyHeadlineStartup => 'Girişim kuruluşu ve danışmanlık';

  @override
  String get demoAuditOrganizationCreated =>
      'Kuruluş oluşturuldu (yalnızca meta veri)';

  @override
  String get demoAuditMemberInvited => 'Üye davet edildi (yalnızca meta veri)';

  @override
  String get demoAuditMemberRoleChanged =>
      'Üye rolü değiştirildi (yalnızca meta veri)';

  @override
  String get demoAuditMembershipSuspended =>
      'Üyelik askıya alındı (yalnızca meta veri)';

  @override
  String get demoAuditDemoAccountDeleted =>
      'Demo hesap silindi (yalnızca meta veri)';

  @override
  String get demoAuditRoleChange => 'rol değişikliği';

  @override
  String get demoAuditInvitationSent => 'davet gönderildi';

  @override
  String get demoAuditSuspensionDenied => 'askıya alma reddedildi';

  @override
  String get homeActivityEmpty => 'Henüz yeni etkinlik yok.';

  @override
  String get discoveryEntrySubtitleConfigured =>
      'Avukat profillerine ve uygulama alanlarına göz atın.';

  @override
  String get searchNoQueryConfigured =>
      'Davalar, belgeler, mesajlar veya avukatlar arasında arama yapmak için bir arama terimi yazın.';

  @override
  String get aiResearchNoMatchesConfigured =>
      'Eşleşme bulunamadı. Farklı kelimeler deneyin.';

  @override
  String get aiResearchEntrySubtitleConfigured =>
      'Araştırma asistanına davalarınız ve belgeleriniz üzerinden sorun — yalnızca tavsiye niteliğinde.';

  @override
  String get errYouDoNotHavePermissionToViewThese2 =>
      'Bu görevleri görüntüleme izniniz yok.';

  @override
  String get errUnableToLoadTasksPleaseTryAgain =>
      'Görevler yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errARejectionNoteIsRequired => 'Ret notu gerekli.';

  @override
  String get errAcknowledgingTheAlertIsTemporarilyUnavailablePleaseTry =>
      'Uyarıyı görüldü olarak işaretlemek geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errApprovalRequestNotFound => 'Onay talebi bulunamadı.';

  @override
  String get errApprovalsAreTemporarilyUnavailablePleaseTryAgain =>
      'Onaylar geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errCancellingTheRequestIsTemporarilyUnavailablePleaseTry =>
      'Talebi iptal etmek geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errComplianceAlertNotFound => 'Uyum uyarısı bulunamadı.';

  @override
  String get errComplianceAlertsAreTemporarilyUnavailablePleaseTryAgain =>
      'Uyum uyarıları geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errCreatingTheAlertIsTemporarilyUnavailablePleaseTry =>
      'Uyarı oluşturmak geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errCreatingTheRequestIsTemporarilyUnavailablePleaseTry =>
      'Talep oluşturmak geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errDecidingTheRequestIsTemporarilyUnavailablePleaseTry =>
      'Talebe karar vermek geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errOnlyAPartnerCanDecideThisRequest =>
      'Bu talebe yalnızca bir ortak karar verebilir.';

  @override
  String get errOnlyAPartnerOrComplianceOfficerCanCreate =>
      'Uyarıları yalnızca bir ortak veya uyum görevlisi oluşturabilir.';

  @override
  String get errOnlyAPartnerOrComplianceOfficerCanResolve =>
      'Uyarıları yalnızca bir ortak veya uyum görevlisi çözebilir.';

  @override
  String get errOnlyAnActiveOrganizationMemberCanAcknowledgeAlerts =>
      'Uyarıları yalnızca etkin bir kuruluş üyesi görüldü olarak işaretleyebilir.';

  @override
  String get errOnlyTheRequesterOrAPartnerCanCancel =>
      'Bu talebi yalnızca talebi oluşturan veya bir ortak iptal edebilir.';

  @override
  String get errResolvingTheAlertIsTemporarilyUnavailablePleaseTry =>
      'Uyarıyı çözmek geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errSelectAnOrganizationToViewApprovals =>
      'Onayları görmek için bir kuruluş seçin.';

  @override
  String get errSelectAnOrganizationToViewComplianceAlerts =>
      'Uyum uyarılarını görmek için bir kuruluş seçin.';

  @override
  String get errTheAlertCanNoLongerBeAcknowledged =>
      'Uyarı artık görüldü olarak işaretlenemiyor.';

  @override
  String get errTheAlertCanNoLongerBeResolved => 'Uyarı artık çözülemiyor.';

  @override
  String get errTheAlertCouldNotBeCreatedCheckThe =>
      'Uyarı oluşturulamadı. Ayrıntıları kontrol edip tekrar deneyin.';

  @override
  String get errTheRequestCanNoLongerBeCancelled =>
      'Talep artık iptal edilemiyor.';

  @override
  String get errTheRequestCouldNotBeCreatedCheckThe =>
      'Talep oluşturulamadı. Ayrıntıları kontrol edip tekrar deneyin.';

  @override
  String get errTheRequestCouldNotBeDecidedItMay =>
      'Talebe karar verilemedi. Talep artık beklemede olmayabilir veya not eksik olabilir.';

  @override
  String get errTheRequestIsNoLongerPending => 'Talep artık beklemede değil.';

  @override
  String get errUnableToAcknowledgeTheAlertPleaseTryAgain =>
      'Uyarı görüldü olarak işaretlenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToCancelTheRequestPleaseTryAgain =>
      'Talep iptal edilemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToCreateTheAlertPleaseTryAgain =>
      'Uyarı oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToCreateTheRequestPleaseTryAgain =>
      'Talep oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToDecideTheRequestPleaseTryAgain =>
      'Talebe karar verilemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadApprovalsPleaseTryAgain =>
      'Onaylar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadComplianceAlertsPleaseTryAgain =>
      'Uyum uyarıları yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToResolveTheAlertPleaseTryAgain =>
      'Uyarı çözülemedi. Lütfen tekrar deneyin.';

  @override
  String get errYouDoNotHavePermissionToCreateApproval =>
      'Onay talebi oluşturma izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewApprovals =>
      'Onayları görüntüleme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewCompliance =>
      'Uyum uyarılarını görüntüleme izniniz yok.';

  @override
  String get errAcknowledgingTheTaskIsTemporarilyUnavailablePleaseTry =>
      'Görevi onaylama geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errAvailableTimesAreTemporarilyUnavailablePleaseTryAgain =>
      'Uygun zamanlar geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errBookingIsTemporarilyUnavailablePleaseTryAgain =>
      'Rezervasyon geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errCreatingTheTaskIsTemporarilyUnavailablePleaseTry =>
      'Görev oluşturma geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String errMessageIsTooLongMaxMaxMessageLengthCharacters(
    int maxMessageLength,
  ) {
    return 'Mesaj çok uzun (en fazla $maxMessageLength karakter).';
  }

  @override
  String get errMessagesAreTemporarilyUnavailablePleaseTryAgain =>
      'Mesajlar geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errOnlyTheAssignedPersonCanAcknowledgeThisTask =>
      'Bu görevi yalnızca atanan kişi onaylayabilir.';

  @override
  String get errReAssigningTheTaskIsTemporarilyUnavailablePlease =>
      'Görevi yeniden atama geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errSendingIsTemporarilyUnavailablePleaseTryAgain =>
      'Gönderme geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errTasksAreTemporarilyUnavailablePleaseTryAgain =>
      'Görevler geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errThatPersonCannotBeAssignedThisTaskChoose =>
      'Bu görev o kişiye atanamaz. Kuruluşun etkin bir üyesini seçin.';

  @override
  String get errThatTimeIsNoLongerAvailableChooseAnother =>
      'Bu saat artık müsait değil. Başka bir saat seçin.';

  @override
  String get errTheBookingDetailsAreInvalidCheckThemAnd =>
      'Rezervasyon ayrıntıları geçersiz. Kontrol edip tekrar deneyin.';

  @override
  String get errTheTaskCannotMoveToThatStatusIt =>
      'Görev bu duruma taşınamaz. Zaten tamamlanmış olabilir.';

  @override
  String get errTheTaskCouldNotBeCreatedCheckThe =>
      'Görev oluşturulamadı. Başlığı kontrol edip tekrar deneyin.';

  @override
  String get errThreadsAreTemporarilyUnavailablePleaseTryAgain =>
      'Mesaj dizileri geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errUnableToAcknowledgeTheTaskPleaseTryAgain =>
      'Görev onaylanamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToConfirmPleaseTryAgain =>
      'Onaylanamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToCreateTheTaskPleaseTryAgain =>
      'Görev oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadAvailableTimesPleaseTryAgain =>
      'Uygun zamanlar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadMessagesPleaseTryAgain =>
      'Mesajlar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadThreadsPleaseTryAgain =>
      'Mesaj dizileri yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToReAssignTheTaskPleaseTry =>
      'Görev yeniden atanamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToSendTheMessagePleaseTryAgain =>
      'Mesaj gönderilemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToUpdateTheTaskPleaseTryAgain =>
      'Görev güncellenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUpdatingTheTaskIsTemporarilyUnavailablePleaseTry =>
      'Görev güncelleme geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errYouDoNotHavePermissionToAdvanceThis =>
      'Bu görevi ilerletme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToBookThis =>
      'Bu danışmayı rezerve etme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToCreateTasks =>
      'Bu dosyada görev oluşturma izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToReAssign =>
      'Bu görevi yeniden atama izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToSendMessages =>
      'Bu mesaj dizisinde mesaj gönderme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewAvailable =>
      'Uygun zamanları görüntüleme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewThese =>
      'Bu mesajları görüntüleme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewThese3 =>
      'Bu mesaj dizilerini görüntüleme izniniz yok.';

  @override
  String get errAttorneyNotFound => 'Avukat bulunamadı.';

  @override
  String get errTheDirectoryIsTemporarilyUnavailableTryAgain =>
      'Dizin geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errTheProfileDetailsAreInvalidCheckThemAnd =>
      'Profil bilgileri geçersiz. Kontrol edip tekrar deneyin.';

  @override
  String get errUnableToLoadTheDirectoryPleaseTryAgain =>
      'Dizin yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errYouDoNotHavePermissionToManageThe =>
      'Dizini yönetme izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewThe =>
      'Dizini görüntüleme izniniz yok.';

  @override
  String get errNotificationsAreTemporarilyUnavailablePleaseTryAgain =>
      'Bildirimler geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errThisFileIsTooLarge => 'Bu dosya çok büyük.';

  @override
  String get errThisFileTypeIsNotSupported => 'Bu dosya türü desteklenmiyor.';

  @override
  String get errUnableToCheckThePaymentStatusPleaseTry =>
      'Ödeme durumu kontrol edilemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadDocumentsPleaseTryAgain =>
      'Belgeler yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadFilesPleaseTryAgain =>
      'Dosyalar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadInvoicesPleaseTryAgain =>
      'Faturalar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadMattersPleaseTryAgain =>
      'Davalar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadNotificationsPleaseTryAgain =>
      'Bildirimler yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToOpenTheFilePleaseTryAgain =>
      'Dosya açılamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToStartThePaymentPleaseTryAgain =>
      'Ödeme başlatılamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToUploadTheFilePleaseTryAgain =>
      'Dosya yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errYouDoNotHavePermissionToUploadFiles =>
      'Bu davaya dosya yükleme izniniz yok.';

  @override
  String get errAIResearchIsNotConfiguredForThisDeployment =>
      'Yapay zekâ araştırması bu dağıtım için yapılandırılmamış. Hiçbir analiz çalıştırılmadı.';

  @override
  String get errAnActionIsAlreadyInProgress =>
      'Zaten devam eden bir işlem var.';

  @override
  String get errEndingTheConsultationIsTemporarilyUnavailablePleaseTry =>
      'Görüşmeyi sonlandırma geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String
  errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest(
    int minQuestionLength,
    int maxQuestionLength,
  ) {
    return '$minQuestionLength ile $maxQuestionLength karakter arasında bir soru girin ve bir kuruluş seçin.';
  }

  @override
  String get errOnlyAPartnerOrAttorneyCanScheduleA =>
      'Video görüşmesini yalnızca bir ortak veya avukat planlayabilir.';

  @override
  String get errOnlyTheCreatorOrAPartnerCanEnd =>
      'Bu görüşmeyi yalnızca oluşturan kişi veya bir ortak sonlandırabilir.';

  @override
  String get errOrganizationMembershipsCouldNotBeLoaded =>
      'Kuruluş üyelikleri yüklenemedi.';

  @override
  String get errSchedulingAConsultationIsTemporarilyUnavailablePleaseTry =>
      'Görüşme planlama geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errSelectAResearchRunToViewItsFindings =>
      'Bulgularını görüntülemek için bir araştırma çalışması seçin.';

  @override
  String get errSelectAVideoConsultationToJoin =>
      'Katılmak için bir video görüşmesi seçin.';

  @override
  String get errSelectAnOrganizationToScheduleAConsultation =>
      'Görüşme planlamak için bir kuruluş seçin.';

  @override
  String get errSelectAnOrganizationToViewResearchRuns =>
      'Araştırma çalışmalarını görüntülemek için bir kuruluş seçin.';

  @override
  String get errSelectAnOrganizationToViewVideoConsultations =>
      'Video görüşmelerini görüntülemek için bir kuruluş seçin.';

  @override
  String get errSignInAgainToUseVideoConsultations =>
      'Video görüşmelerini kullanmak için tekrar oturum açın.';

  @override
  String get errStartingTheConsultationIsTemporarilyUnavailablePleaseTry =>
      'Görüşmeyi başlatma geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errTheAIProviderReturnedAnUnexpectedResponsePlease =>
      'Yapay zekâ sağlayıcısı beklenmeyen bir yanıt döndürdü. Lütfen tekrar deneyin.';

  @override
  String get errTheConsultationCouldNotBeScheduledCheckThe =>
      'Görüşme planlanamadı. Ayrıntıları kontrol edip tekrar deneyin.';

  @override
  String get errTheConsultationIsNotAvailableToJoinRight =>
      'Görüşmeye şu anda katılmak mümkün değil.';

  @override
  String get errTheSelectedContextIsTooLargeRemoveDocuments =>
      'Seçilen bağlam çok büyük. Bazı belgeleri kaldırıp tekrar deneyin.';

  @override
  String get errTheSelectedResearchRunWasNotFound =>
      'Seçilen araştırma çalışması bulunamadı.';

  @override
  String get errThisConsultationCanNoLongerBeEnded =>
      'Bu görüşme artık sonlandırılamaz.';

  @override
  String get errThisConsultationCanNoLongerBeStarted =>
      'Bu görüşme artık başlatılamaz.';

  @override
  String get errThisVideoConsultationHasAlreadyEnded =>
      'Bu video görüşmesi zaten sona erdi.';

  @override
  String get errThisVideoConsultationWasNotFound =>
      'Bu video görüşmesi bulunamadı.';

  @override
  String get errUnableToEndTheConsultationPleaseTryAgain =>
      'Görüşme sonlandırılamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToJoinTheConsultationPleaseTryAgain =>
      'Görüşmeye katılınamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToLoadVideoConsultationsPleaseTryAgain =>
      'Video görüşmeleri yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get errUnableToReadTheVideoConsultationPleaseTry =>
      'Video görüşmesi okunamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToRunAIResearchPleaseTryAgain =>
      'Yapay zekâ araştırması çalıştırılamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToScheduleTheConsultationPleaseTryAgain =>
      'Görüşme planlanamadı. Lütfen tekrar deneyin.';

  @override
  String get errUnableToStartTheConsultationPleaseTryAgain =>
      'Görüşme başlatılamadı. Lütfen tekrar deneyin.';

  @override
  String get errVideoCallsAreNotConfiguredForThisDeployment =>
      'Video aramaları bu dağıtım için yapılandırılmamış. Hiçbir arama başlatılmadı.';

  @override
  String get errVideoCallsAreTemporarilyUnavailablePleaseTryAgain =>
      'Video aramaları geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errVideoConsultationsAreTemporarilyUnavailablePleaseTryAgain =>
      'Video görüşmeleri geçici olarak kullanılamıyor. Lütfen tekrar deneyin.';

  @override
  String get errWeCouldnTCompleteThatRequestPleaseTry =>
      'Bu isteği tamamlayamadık. Lütfen tekrar deneyin.';

  @override
  String get errYouDoNotHavePermissionToJoinThis =>
      'Bu görüşmeye katılma izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToStartThis =>
      'Bu görüşmeyi başlatma izniniz yok.';

  @override
  String get errYouDoNotHavePermissionToViewVideo =>
      'Video görüşmelerini görüntüleme izniniz yok.';
}
