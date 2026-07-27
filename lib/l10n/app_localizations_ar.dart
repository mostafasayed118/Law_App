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
}
