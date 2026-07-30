import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LegalHub'**
  String get appTitle;

  /// No description provided for @accessTitle.
  ///
  /// In en, this message translates to:
  /// **'Access the foundation'**
  String get accessTitle;

  /// No description provided for @accessBody.
  ///
  /// In en, this message translates to:
  /// **'This bootstrap uses a local demo session only. No credentials are collected or sent.'**
  String get accessBody;

  /// No description provided for @continueAsDemo.
  ///
  /// In en, this message translates to:
  /// **'Continue with demo session'**
  String get continueAsDemo;

  /// No description provided for @demoSessionNotice.
  ///
  /// In en, this message translates to:
  /// **'Development-only demo session'**
  String get demoSessionNotice;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Foundation workspace'**
  String get homeTitle;

  /// No description provided for @homeBody.
  ///
  /// In en, this message translates to:
  /// **'This placeholder proves the theme, localization, RTL wiring, and shared view states. No legal or client data is loaded.'**
  String get homeBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Placeholder role'**
  String get roleLabel;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get roleClient;

  /// No description provided for @roleAttorney.
  ///
  /// In en, this message translates to:
  /// **'Attorney'**
  String get roleAttorney;

  /// No description provided for @rolePartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get rolePartner;

  /// No description provided for @roleComplianceOfficer.
  ///
  /// In en, this message translates to:
  /// **'Compliance officer'**
  String get roleComplianceOfficer;

  /// No description provided for @roleResearchAnalyst.
  ///
  /// In en, this message translates to:
  /// **'Research analyst'**
  String get roleResearchAnalyst;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @homeNavigation.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavigation;

  /// No description provided for @settingsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsNavigation;

  /// No description provided for @stateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get stateSuccess;

  /// No description provided for @stateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get stateEmpty;

  /// No description provided for @stateError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this placeholder'**
  String get stateError;

  /// No description provided for @stateOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get stateOffline;

  /// No description provided for @stateUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Access not available'**
  String get stateUnauthorized;

  /// No description provided for @stateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get stateLoading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @foundationReady.
  ///
  /// In en, this message translates to:
  /// **'Foundation ready'**
  String get foundationReady;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'End demo session'**
  String get signOut;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @signInWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get signInWelcome;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your secure legal workstation.'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// No description provided for @emailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. counsel@firm.com'**
  String get emailPlaceholder;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get passwordPlaceholder;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'OR CONTINUE WITH'**
  String get orContinueWith;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get continueWithApple;

  /// No description provided for @newToLegalHub.
  ///
  /// In en, this message translates to:
  /// **'New to LegalHub?'**
  String get newToLegalHub;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccount;

  /// No description provided for @encryptedConnectionNotice.
  ///
  /// In en, this message translates to:
  /// **'256-BIT ENCRYPTED CONNECTION'**
  String get encryptedConnectionNotice;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your details to register your practice.'**
  String get signUpSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @fullNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Jane Doe'**
  String get fullNamePlaceholder;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// No description provided for @phonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'+1 (555) 000-0000'**
  String get phonePlaceholder;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters.'**
  String get passwordHint;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Conditions and Privacy Policy.'**
  String get agreeToTerms;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUpButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInLink;

  /// No description provided for @recoverPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Password'**
  String get recoverPasswordTitle;

  /// No description provided for @recoverPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email address to receive a verification code.'**
  String get recoverPasswordBody;

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCodeButton;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// No description provided for @codeSentNotice.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your inbox.'**
  String get codeSentNotice;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit code to your email address.'**
  String get verifyEmailBody;

  /// No description provided for @verifyAndContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyAndContinueButton;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @resendHelp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the email? Check your spam folder or contact support.'**
  String get resendHelp;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordButton;

  /// No description provided for @resetSuccessNotice.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset. You can sign in now.'**
  String get resetSuccessNotice;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Expert Legal Advice'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Connect seamlessly with top-tier legal professionals. Unparalleled expertise tailored for your most critical and complex matters.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Case Tracking'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Monitor your legal matters in real-time with precise updates. Stay informed at every procedural step with our structured timeline view.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Secure Communication'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Confidential messaging utilizing state-of-the-art encryption protocols. Your attorney-client privilege, protected in the digital realm.'**
  String get onboardingDesc3;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get skip;

  /// No description provided for @onboardingSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set'**
  String get onboardingSuccessTitle;

  /// No description provided for @onboardingSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your secure legal workstation is ready. Sign in to begin.'**
  String get onboardingSuccessBody;

  /// No description provided for @onboardingSuccessAction.
  ///
  /// In en, this message translates to:
  /// **'Continue to Sign In'**
  String get onboardingSuccessAction;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How can we assist you with your legal needs today?'**
  String get homeSubtitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Find a lawyer or legal topic...'**
  String get searchPlaceholder;

  /// No description provided for @practiceAreas.
  ///
  /// In en, this message translates to:
  /// **'Practice Areas'**
  String get practiceAreas;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL'**
  String get viewAll;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @areaCriminal.
  ///
  /// In en, this message translates to:
  /// **'Criminal'**
  String get areaCriminal;

  /// No description provided for @areaCivil.
  ///
  /// In en, this message translates to:
  /// **'Civil'**
  String get areaCivil;

  /// No description provided for @areaCorporate.
  ///
  /// In en, this message translates to:
  /// **'Corporate'**
  String get areaCorporate;

  /// No description provided for @areaFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get areaFamily;

  /// No description provided for @activeCaseChip.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE CASE'**
  String get activeCaseChip;

  /// No description provided for @actionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequiredTitle;

  /// No description provided for @actionRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Signature needed for retainer agreement.'**
  String get actionRequiredBody;

  /// No description provided for @consultationTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get consultationTitle;

  /// No description provided for @consultationBody.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow at 2:00 PM via Video Call.'**
  String get consultationBody;

  /// No description provided for @casesNavigation.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get casesNavigation;

  /// No description provided for @messagesNavigation.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesNavigation;

  /// No description provided for @profileNavigation.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNavigation;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
