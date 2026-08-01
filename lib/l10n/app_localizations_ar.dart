// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'LegalHub';

  @override
  String get accessTitle => 'الوصول إلى الأساس';

  @override
  String get accessBody =>
      'يستخدم هذا الإصدار جلسة تجريبية محلية فقط. لا يتم جمع بيانات اعتماد أو إرسالها.';

  @override
  String get continueAsDemo => 'المتابعة بجلسة تجريبية';

  @override
  String get demoSessionNotice => 'جلسة تجريبية للتطوير فقط';

  @override
  String get homeTitle => 'مساحة العمل الأساسية';

  @override
  String get homeBody =>
      'تثبت هذه الشاشة المؤقتة المظهر والتعريب ودعم الاتجاه من اليمين إلى اليسار وحالات العرض المشتركة. لا يتم تحميل بيانات قانونية أو بيانات عملاء.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get roleLabel => 'الدور المؤقت';

  @override
  String get roleClient => 'العميل';

  @override
  String get roleAttorney => 'المحامي';

  @override
  String get rolePartner => 'الشريك';

  @override
  String get roleComplianceOfficer => 'مسؤول الامتثال';

  @override
  String get roleResearchAnalyst => 'محلل الأبحاث';

  @override
  String get roleAdmin => 'المسؤول';

  @override
  String get homeNavigation => 'الرئيسية';

  @override
  String get settingsNavigation => 'الإعدادات';

  @override
  String get stateSuccess => 'جاهز';

  @override
  String get stateEmpty => 'لا يوجد ما يُعرض';

  @override
  String get stateError => 'تعذر تحميل هذه الشاشة المؤقتة';

  @override
  String get stateOffline => 'غير متصل';

  @override
  String get stateUnauthorized => 'الوصول غير متاح';

  @override
  String get stateLoading => 'جارٍ التحميل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get foundationReady => 'الأساس جاهز';

  @override
  String get signOut => 'إنهاء الجلسة التجريبية';

  @override
  String get back => 'رجوع';

  @override
  String get signInWelcome => 'مرحبًا بعودتك';

  @override
  String get signInSubtitle =>
      'سجّل الدخول للوصول إلى محطة العمل القانونية الآمنة.';

  @override
  String get emailLabel => 'عنوان البريد الإلكتروني';

  @override
  String get emailPlaceholder => 'مثال: counsel@firm.com';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get passwordPlaceholder => '••••••••';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get signInButton => 'تسجيل الدخول';

  @override
  String get orContinueWith => 'أو تابع باستخدام';

  @override
  String get continueWithGoogle => 'Google';

  @override
  String get continueWithApple => 'Apple';

  @override
  String get newToLegalHub => 'جديد على LegalHub؟';

  @override
  String get createAccount => 'أنشئ حسابًا';

  @override
  String get encryptedConnectionNotice => 'اتصال مشفّر 256-بت';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpSubtitle => 'أدخل بياناتك لتسجيل ممارستك.';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get fullNamePlaceholder => 'جين دو';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get phonePlaceholder => '+1 (555) 000-0000';

  @override
  String get passwordHint => 'يجب أن تكون ٨ أحرف على الأقل.';

  @override
  String get agreeToTerms => 'أوافق على الشروط والأحكام وسياسة الخصوصية.';

  @override
  String get signUpButton => 'إنشاء حساب';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get signInLink => 'تسجيل الدخول';

  @override
  String get recoverPasswordTitle => 'استعادة كلمة المرور';

  @override
  String get recoverPasswordBody =>
      'أدخل بريدك الإلكتروني المسجّل لتصلك رمز التحقق.';

  @override
  String get sendCodeButton => 'إرسال الرمز';

  @override
  String get backToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get codeSentNotice => 'أُرسل رمز التحقق إلى بريدك الوارد.';

  @override
  String get verifyEmailTitle => 'تأكيد البريد الإلكتروني';

  @override
  String get verifyEmailBody =>
      'لقد أرسلنا رمزًا من ٦ أرقام إلى بريدك الإلكتروني.';

  @override
  String get verifyAndContinueButton => 'تأكيد ومتابعة';

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String get resendCodeUnavailable =>
      'إعادة إرسال الرمز (غير متاح في النسخة التجريبية)';

  @override
  String get resendHelp =>
      'لم يصلك البريد؟ تحقق من مجلد الرسائل غير المرغوبة أو تواصل مع الدعم.';

  @override
  String get resetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get resetPasswordButton => 'إعادة تعيين كلمة المرور';

  @override
  String get resetSuccessNotice =>
      'تمت إعادة تعيين كلمة المرور. يمكنك تسجيل الدخول الآن.';

  @override
  String get onboardingTitle1 => 'استشارة قانونية احترافية';

  @override
  String get onboardingDesc1 =>
      'تواصل بسلاسة مع نخبة المحترفين القانونيين. خبرة لا تضاهى مصممة لأهم قضاياك وأكثرها تعقيدًا.';

  @override
  String get onboardingTitle2 => 'تتبّع القضايا';

  @override
  String get onboardingDesc2 =>
      'راقب مسائل القانونية لحظة بلحظة مع تحديثات دقيقة. ابقَ على اطلاع في كل خطوة إجرائية عبر عرض الجدول الزمني المنظم.';

  @override
  String get onboardingTitle3 => 'اتصال آمن';

  @override
  String get onboardingDesc3 =>
      'مراسلة سرية تستخدم أحدث بروتوكولات التشفير. امتيازك المحامي-العميل، محمي في الفضاء الرقمي.';

  @override
  String get onboardingContinue => 'متابعة';

  @override
  String get onboardingGetStarted => 'ابدأ الآن';

  @override
  String get skip => 'تخطٍ';

  @override
  String get onboardingSuccessTitle => 'أنت جاهز';

  @override
  String get onboardingSuccessBody =>
      'محطة العمل القانونية الآمنة جاهزة. سجّل الدخول للبدء.';

  @override
  String get onboardingSuccessAction => 'المتابعة إلى تسجيل الدخول';

  @override
  String homeGreeting(String name) {
    return 'مرحبًا، $name';
  }

  @override
  String get homeFallbackName => 'ضيف';

  @override
  String get homeSubtitle => 'كيف يمكننا مساعدتك في احتياجاتك القانونية اليوم؟';

  @override
  String get searchPlaceholder => 'ابحث عن محامٍ أو موضوع قانوني...';

  @override
  String get practiceAreas => 'مجالات الممارسة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get recentActivity => 'النشاط الأخير';

  @override
  String get areaCriminal => 'جنائي';

  @override
  String get areaCivil => 'مدني';

  @override
  String get areaCorporate => 'شركات';

  @override
  String get areaFamily => 'أحوال شخصية';

  @override
  String get activeCaseChip => 'قضية نشطة';

  @override
  String get activeCaseTime => 'اليوم، ١٠:٠٠ صباحًا';

  @override
  String get activeCaseTitle => 'تركة هـ. فانس ضد المدينة';

  @override
  String get activeCaseBody =>
      'جلسة مقررة لأمر أولي بمنع مؤقت بشأن نزاع حدود العقار في المحكمة الجزئية.';

  @override
  String get activeCaseAttorney => 'المحامي ر. ستيرلينغ';

  @override
  String get actionRequiredTitle => 'إجراء مطلوب';

  @override
  String get actionRequiredBody => 'يلزم التوقيع على اتفاقية الأتعاب.';

  @override
  String get consultationTitle => 'استشارة';

  @override
  String get consultationBody => 'غدًا الساعة ٢:٠٠ مساءً عبر مكالمة فيديو.';

  @override
  String get signInErrorNotice => 'تعذر بدء الجلسة التجريبية.';

  @override
  String get casesNavigation => 'القضايا';

  @override
  String get messagesNavigation => 'الرسائل';

  @override
  String get profileNavigation => 'الملف';

  @override
  String get profileNameLabel => 'الاسم';

  @override
  String get profileAccountIdLabel => 'معرّف الحساب';

  @override
  String get profileRoleLabel => 'الدور';

  @override
  String get profileExpiresLabel => 'تنتهي الجلسة';

  @override
  String get profileSessionExpired =>
      'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsNote =>
      'تُحفظ التفضيلات على هذا الجهاز. تسليم الإشعارات مُخطط له في إصدار لاحق.';

  @override
  String get notifAppointmentReminders => 'تذكيرات المواعيد';

  @override
  String get notifActivityUpdates => 'تحديثات النشاط';

  @override
  String get notifSystemAlerts => 'تنبيهات النظام';
}
