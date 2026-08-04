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
  String get signUpErrorEmailInUse =>
      'يوجد حساب بهذا البريد الإلكتروني بالفعل.';

  @override
  String get signUpErrorRateLimited =>
      'محاولات كثيرة جدًا. يرجى المحاولة لاحقًا.';

  @override
  String get signUpErrorServiceUnavailable =>
      'خدمة إنشاء الحساب غير متاحة مؤقتًا. يرجى المحاولة لاحقًا.';

  @override
  String get signUpErrorGeneric => 'فشل إنشاء الحساب. يرجى المحاولة لاحقًا.';

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
  String get signInErrorNotice =>
      'تعذر تسجيل الدخول. يرجى التحقق من بياناتك والمحاولة مرة أخرى.';

  @override
  String get validatorRequired => 'هذا الحقل مطلوب.';

  @override
  String get validatorEmailInvalid => 'أدخل عنوان بريد إلكتروني صالح.';

  @override
  String validatorMinLength(int count) {
    return 'يجب أن يكون على الأقل $count أحرف.';
  }

  @override
  String get validatorMismatch => 'كلمتا المرور غير متطابقتين.';

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
  String get deleteAccountAction => 'حذف الحساب';

  @override
  String get deleteAccountConfirmTitle => 'هل تريد حذف حسابك؟';

  @override
  String get deleteAccountConfirmBody =>
      'سيؤدي هذا إلى حذف حسابك نهائيًا وإزالتك من كل مؤسسة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteAccountConfirmAction => 'حذف';

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

  @override
  String get cancel => 'إلغاء';

  @override
  String get orgTitle => 'المؤسسة';

  @override
  String get createOrgTitle => 'إنشاء مؤسسة';

  @override
  String get createOrgSubtitle => 'أعطِ شركتك اسمًا. ستصبح شريكها الأول.';

  @override
  String get orgNameLabel => 'اسم المؤسسة';

  @override
  String get orgNamePlaceholder => 'مثال: ستيرلينغ وشركاه';

  @override
  String get createOrgButton => 'إنشاء مؤسسة';

  @override
  String get rosterTitle => 'الأعضاء';

  @override
  String get rosterEmpty => 'لا يوجد أعضاء بعد.';

  @override
  String get orgSwitcherLabel => 'المؤسسة';

  @override
  String get acceptInvitationTitle => 'قبول دعوة';

  @override
  String get acceptInvitationBody =>
      'الصق الرمز لمرة واحدة الذي شاركه معك الشريك.';

  @override
  String get acceptInvitationAction => 'قبول';

  @override
  String get invitationAccepted => 'تم قبول الدعوة.';

  @override
  String get invitationAcceptedBody => 'انضممت إلى المؤسسة.';

  @override
  String get done => 'تم';

  @override
  String get inviteMember => 'دعوة عضو';

  @override
  String get inviteEmailLabel => 'الدعوة عبر البريد الإلكتروني';

  @override
  String get inviteRoleLabel => 'تعيين الدور';

  @override
  String get inviteTokenLabel => 'رمز لمرة واحدة';

  @override
  String get inviteSendButton => 'إرسال الدعوة';

  @override
  String inviteTokenBody(String email) {
    return 'شارك رمز الاستخدام لمرة واحدة هذا مع $email. لا يمكن عرضه مرة أخرى.';
  }

  @override
  String get inviteTokenCopy => 'نسخ الرمز';

  @override
  String get inviteTokenCopied => 'تم نسخ الرمز إلى الحافظة.';

  @override
  String get actionResendInvitation => 'إعادة إرسال الدعوة';

  @override
  String get actionRevokeInvitation => 'إلغاء الدعوة';

  @override
  String get invitationRevoked => 'تم إلغاء الدعوة.';

  @override
  String inviteTokenResentBody(String email) {
    return 'رمز جديد لمرة واحدة لـ $email. لا يمكن عرضه مرة أخرى.';
  }

  @override
  String get memberStatusInvited => 'مدعو';

  @override
  String get memberStatusActive => 'نشط';

  @override
  String get memberStatusSuspended => 'موقوف';

  @override
  String get memberStatusRemoved => 'مزال';

  @override
  String get actionSuspend => 'إيقاف';

  @override
  String get actionReactivate => 'إعادة التفعيل';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get removeMemberConfirmTitle => 'إزالة العضو؟';

  @override
  String removeMemberConfirmBody(String name) {
    return 'إزالة $name من هذه المؤسسة؟';
  }

  @override
  String get removeMemberConfirmAction => 'إزالة';

  @override
  String get orgErrorDenied => 'ليس لديك صلاحية تنفيذ هذا الإجراء.';

  @override
  String get orgErrorDuplicateMember => 'هذا الشخص عضو بالفعل في المؤسسة.';

  @override
  String get orgErrorLastPartner =>
      'يجب أن تحتفظ المؤسسة بشريك نشط واحد على الأقل.';

  @override
  String get orgErrorInvalidRole => 'لا يمكن تعيين هذا الدور.';

  @override
  String get orgErrorInvalidName => 'لا يمكن أن يكون اسم المؤسسة فارغًا.';

  @override
  String get orgErrorInvalidInvitation => 'الدعوة غير صالحة أو منتهية.';

  @override
  String get orgErrorProviderUnavailable =>
      'الخدمة غير متاحة الآن. حاول مرة أخرى.';

  @override
  String get orgErrorUnknown => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get signUpCheckInboxTitle => 'تحقق من بريدك الوارد';

  @override
  String get signUpCheckInboxBody =>
      'أرسلنا رابط التحقق إلى بريدك الإلكتروني. افتحه لتفعيل حسابك، ثم سجّل الدخول.';

  @override
  String get signUpCheckInboxAction => 'المتابعة إلى تسجيل الدخول';

  @override
  String get bookingTitle => 'احجز استشارة';

  @override
  String get bookingLocalOnlyNote =>
      'وضع تجريبي — لا يتم حجز أي استشارة أو إرسالها فعليًا.';

  @override
  String get bookingCategoryStepTitle => 'نوع الاستشارة';

  @override
  String get bookingCategoryGeneral => 'عامة';

  @override
  String get bookingCategoryFollowUp => 'متابعة';

  @override
  String get bookingCategoryUrgent => 'عاجلة';

  @override
  String get bookingTopicLabel => 'الموضوع (اختياري)';

  @override
  String get bookingTopicPlaceholder => 'صف سؤالك باختصار';

  @override
  String get bookingContinue => 'متابعة';

  @override
  String get bookingSelectDateTimeStep => 'اختر التاريخ والوقت';

  @override
  String get bookingSlotsEmpty => 'لا توجد أوقات متاحة.';

  @override
  String get bookingSlotsError => 'تعذّر تحميل الأوقات المتاحة.';

  @override
  String bookingDurationMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get bookingReviewStep => 'مراجعة الحجز';

  @override
  String get bookingSummaryType => 'النوع';

  @override
  String get bookingSummaryTopic => 'الموضوع';

  @override
  String get bookingSummaryTime => 'الوقت';

  @override
  String get bookingSummaryNotSet => 'غير محدد';

  @override
  String get bookingEditCategory => 'تعديل النوع';

  @override
  String get bookingConfirm => 'تأكيد الحجز';

  @override
  String get bookingConfirmFailed => 'تعذّر التأكيد. حاول مرة أخرى.';

  @override
  String get bookingSuccessTitle => 'تم تأكيد الحجز';

  @override
  String bookingSuccessBody(String referenceId) {
    return 'المرجع: $referenceId';
  }

  @override
  String get bookingDone => 'تم';

  @override
  String get bookingEntryTitle => 'احجز استشارة';

  @override
  String get bookingEntrySubtitle => 'جدولة استشارة — عرض تجريبي للتطوير.';

  @override
  String get discoveryTitle => 'ابحث عن محامٍ';

  @override
  String get discoverySearchHint => 'ابحث بالاسم أو مجال الممارسة';

  @override
  String get discoveryFilterAll => 'الكل';

  @override
  String get discoveryEmpty => 'لا يوجد محامون يطابقون بحثك.';

  @override
  String get discoveryError => 'تعذّر تحميل المحامين.';

  @override
  String get discoveryLocalOnlyNote =>
      'وضع تجريبي — ملفات تعريفية اصطناعية فقط. لا يتم عرض محامين حقيقيين أو التواصل معهم.';

  @override
  String get discoveryEntryTitle => 'ابحث عن محامٍ';

  @override
  String get discoveryEntrySubtitle =>
      'تصفح ملفات المحامين التجريبية — عرض تجريبي للتطوير.';

  @override
  String get bookingSummaryAttorney => 'المحامي';

  @override
  String bookingAttorneyPrefill(String name) {
    return 'الحجز مع $name';
  }

  @override
  String get discoveryProfileTitle => 'ملف المحامي';

  @override
  String get discoveryProfileNotFound => 'المحامي غير موجود.';

  @override
  String get discoveryProfileBio => 'نبذة';

  @override
  String get discoveryProfileBook => 'احجز مع هذا المحامي';

  @override
  String get matterTitle => 'القضايا';

  @override
  String get matterFilterAll => 'الكل';

  @override
  String get matterStatusOpen => 'مفتوحة';

  @override
  String get matterStatusActive => 'نشطة';

  @override
  String get matterStatusClosed => 'مغلقة';

  @override
  String get matterEmpty => 'لا توجد قضايا تطابق عامل التصفية.';

  @override
  String get matterError => 'تعذّر تحميل القضايا.';

  @override
  String get matterLocalOnlyNote =>
      'وضع تجريبي — قضايا اصطناعية فقط. لا يتم عرض قضايا حقيقية.';

  @override
  String get matterEntryTitle => 'قضاياي';

  @override
  String get matterEntrySubtitle =>
      'تصفح ملفات القضايا التجريبية — عرض تجريبي للتطوير.';

  @override
  String get matterDetailsTitle => 'تفاصيل القضية';

  @override
  String get matterDetailsNotFound => 'القضية غير موجودة.';

  @override
  String get matterDetailsPracticeArea => 'مجال الممارسة';

  @override
  String get matterDetailsAssignedAttorney => 'المحامي المكلَّف';

  @override
  String get matterDetailsCreated => 'تاريخ الإنشاء';

  @override
  String get vaultTitle => 'المستندات';

  @override
  String get vaultEmpty => 'لا توجد مستندات متاحة.';

  @override
  String get vaultError => 'تعذّر تحميل المستندات.';

  @override
  String get vaultLocalOnlyNote =>
      'وضع تجريبي — بيانات وصفية اصطناعية للمستندات فقط. لا يتم عرض ملفات حقيقية.';

  @override
  String get viewMatter => 'عرض القضية';

  @override
  String get vaultEntryTitle => 'خزنة المستندات';

  @override
  String get vaultEntrySubtitle =>
      'تصفح البيانات الوصفية للمستندات التجريبية — عرض تجريبي للتطوير.';

  @override
  String get documentTypeContract => 'عقد';

  @override
  String get documentTypeBrief => 'مذكرة';

  @override
  String get documentTypeEvidence => 'دليل';

  @override
  String get documentTypeCorrespondence => 'مراسلات';

  @override
  String get messagesTitle => 'الرسائل';

  @override
  String get messagesEmpty => 'لا توجد محادثات متاحة.';

  @override
  String get messagesError => 'تعذّر تحميل المحادثات.';

  @override
  String get messagesLocalOnlyNote =>
      'وضع تجريبي — بيانات وصفية اصطناعية للمحادثات فقط. لا يتم عرض رسائل حقيقية.';

  @override
  String get messagesEntryTitle => 'الرسائل';

  @override
  String get messagesEntrySubtitle =>
      'تصفح محادثات تجريبية — عرض تجريبي للتطوير.';

  @override
  String messagesMessageCount(Object count) {
    return '$count رسائل';
  }

  @override
  String get searchTitle => 'بحث';

  @override
  String get searchNoQuery =>
      'اكتب كلمة بحث للعثور على القضايا أو المستندات أو الرسائل أو المحامين التجريبية.';

  @override
  String get searchEmpty => 'لا توجد نتائج مطابقة لبحثك.';

  @override
  String get searchError => 'تعذّر تشغيل البحث.';

  @override
  String get searchLocalOnlyNote =>
      'وضع تجريبي — النتائج من قوائم اصطناعية فقط. لا يتم البحث في أي بيانات حقيقية.';

  @override
  String get matterWorkspaceDocumentsTitle => 'المستندات';

  @override
  String get matterWorkspaceDocumentsEmpty =>
      'لا توجد مستندات متاحة لهذه القضية.';

  @override
  String get matterWorkspaceMessagesTitle => 'الرسائل';

  @override
  String get matterWorkspaceMessagesEmpty =>
      'لا توجد محادثات متاحة لهذه القضية.';
}
