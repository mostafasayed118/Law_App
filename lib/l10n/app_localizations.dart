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

  /// No description provided for @sessionNoticeConfigured.
  ///
  /// In en, this message translates to:
  /// **'Live session — data comes from the server.'**
  String get sessionNoticeConfigured;

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

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

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
  /// **'Something went wrong. Please try again.'**
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

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'End demo session'**
  String get signOut;

  /// No description provided for @signOutConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutConfigured;

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

  /// No description provided for @socialSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Social sign-in is not available yet. Use email or the demo session.'**
  String get socialSignInUnavailable;

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

  /// No description provided for @signUpErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get signUpErrorEmailInUse;

  /// No description provided for @signUpErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get signUpErrorRateLimited;

  /// No description provided for @signUpErrorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-up is temporarily unavailable. Please try again.'**
  String get signUpErrorServiceUnavailable;

  /// No description provided for @signUpErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get signUpErrorGeneric;

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
  /// **'At least 12 characters with 3 of 4: uppercase, lowercase, digit, symbol.'**
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

  /// No description provided for @recoveryErrorNotice.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete that request. Please try again.'**
  String get recoveryErrorNotice;

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

  /// No description provided for @otpIncompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code to continue.'**
  String get otpIncompleteHint;

  /// No description provided for @notifTypeInvoiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Invoice issued'**
  String get notifTypeInvoiceStatus;

  /// No description provided for @notifTypeMatterUpdated.
  ///
  /// In en, this message translates to:
  /// **'Matter updated'**
  String get notifTypeMatterUpdated;

  /// No description provided for @notifTypeAppointmentReminder.
  ///
  /// In en, this message translates to:
  /// **'Appointment reminder'**
  String get notifTypeAppointmentReminder;

  /// No description provided for @notifTypeMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'Message received'**
  String get notifTypeMessageReceived;

  /// No description provided for @notifTypeSystemMaintenance.
  ///
  /// In en, this message translates to:
  /// **'System maintenance'**
  String get notifTypeSystemMaintenance;

  /// No description provided for @notifSummaryInvoiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Demo notification — invoice issued'**
  String get notifSummaryInvoiceStatus;

  /// No description provided for @notifSummaryMatterUpdated.
  ///
  /// In en, this message translates to:
  /// **'Demo notification — matter status update'**
  String get notifSummaryMatterUpdated;

  /// No description provided for @notifSummaryAppointmentReminder.
  ///
  /// In en, this message translates to:
  /// **'Demo notification — consultation reminder'**
  String get notifSummaryAppointmentReminder;

  /// No description provided for @notifSummaryMessageReceived.
  ///
  /// In en, this message translates to:
  /// **'Demo notification — new message in thread'**
  String get notifSummaryMessageReceived;

  /// No description provided for @notifSummarySystemMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Demo notification — scheduled maintenance'**
  String get notifSummarySystemMaintenance;

  /// No description provided for @demoMatterTitle1.
  ///
  /// In en, this message translates to:
  /// **'Demo acquisition review'**
  String get demoMatterTitle1;

  /// No description provided for @demoMatterTitle2.
  ///
  /// In en, this message translates to:
  /// **'Commercial lease consultation'**
  String get demoMatterTitle2;

  /// No description provided for @demoMatterTitle3.
  ///
  /// In en, this message translates to:
  /// **'Procedural review matter'**
  String get demoMatterTitle3;

  /// No description provided for @demoMatterTitle4.
  ///
  /// In en, this message translates to:
  /// **'Family status consultation'**
  String get demoMatterTitle4;

  /// No description provided for @demoMatterTitle5.
  ///
  /// In en, this message translates to:
  /// **'Startup formation advisory'**
  String get demoMatterTitle5;

  /// No description provided for @demoAttorneyBio1.
  ///
  /// In en, this message translates to:
  /// **'Corporate transactions and governance counsel.'**
  String get demoAttorneyBio1;

  /// No description provided for @demoAttorneyBio2.
  ///
  /// In en, this message translates to:
  /// **'Civil litigation and contracts.'**
  String get demoAttorneyBio2;

  /// No description provided for @demoAttorneyBio3.
  ///
  /// In en, this message translates to:
  /// **'Criminal defense and procedure.'**
  String get demoAttorneyBio3;

  /// No description provided for @demoAttorneyBio4.
  ///
  /// In en, this message translates to:
  /// **'Family law and personal status matters.'**
  String get demoAttorneyBio4;

  /// No description provided for @demoAttorneyBio5.
  ///
  /// In en, this message translates to:
  /// **'Startup formation and advisory work.'**
  String get demoAttorneyBio5;

  /// No description provided for @demoThreadTitle1.
  ///
  /// In en, this message translates to:
  /// **'Demo matter updates'**
  String get demoThreadTitle1;

  /// No description provided for @demoThreadTitle2.
  ///
  /// In en, this message translates to:
  /// **'Consultation follow-up — demo'**
  String get demoThreadTitle2;

  /// No description provided for @demoThreadTitle3.
  ///
  /// In en, this message translates to:
  /// **'Demo procedural notes'**
  String get demoThreadTitle3;

  /// No description provided for @demoThreadTitle4.
  ///
  /// In en, this message translates to:
  /// **'Family matter thread — demo'**
  String get demoThreadTitle4;

  /// No description provided for @demoThreadTitle5.
  ///
  /// In en, this message translates to:
  /// **'Startup advisory — demo'**
  String get demoThreadTitle5;

  /// No description provided for @demoMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Demo message {count} — generic demo content, no real client or legal data.'**
  String demoMessageBody(int count);

  /// No description provided for @demoAuthorAttorney.
  ///
  /// In en, this message translates to:
  /// **'Demo attorney'**
  String get demoAuthorAttorney;

  /// No description provided for @demoAuthorClient.
  ///
  /// In en, this message translates to:
  /// **'Demo client'**
  String get demoAuthorClient;

  /// No description provided for @demoDocumentTitle1.
  ///
  /// In en, this message translates to:
  /// **'Demo engagement letter'**
  String get demoDocumentTitle1;

  /// No description provided for @demoDocumentTitle2.
  ///
  /// In en, this message translates to:
  /// **'Sample matter brief — demo'**
  String get demoDocumentTitle2;

  /// No description provided for @demoDocumentTitle3.
  ///
  /// In en, this message translates to:
  /// **'Demo evidence index'**
  String get demoDocumentTitle3;

  /// No description provided for @demoDocumentTitle4.
  ///
  /// In en, this message translates to:
  /// **'Correspondence log — demo'**
  String get demoDocumentTitle4;

  /// No description provided for @demoDocumentTitle5.
  ///
  /// In en, this message translates to:
  /// **'Demo settlement draft'**
  String get demoDocumentTitle5;

  /// No description provided for @demoFileName1.
  ///
  /// In en, this message translates to:
  /// **'Demo retainer scan'**
  String get demoFileName1;

  /// No description provided for @demoFileName2.
  ///
  /// In en, this message translates to:
  /// **'Demo lease annex'**
  String get demoFileName2;

  /// No description provided for @demoFileName3.
  ///
  /// In en, this message translates to:
  /// **'Demo evidence register'**
  String get demoFileName3;

  /// No description provided for @demoFileName4.
  ///
  /// In en, this message translates to:
  /// **'Demo correspondence copy'**
  String get demoFileName4;

  /// No description provided for @demoFileName5.
  ///
  /// In en, this message translates to:
  /// **'Demo formation checklist'**
  String get demoFileName5;

  /// No description provided for @demoAlertTitle1.
  ///
  /// In en, this message translates to:
  /// **'Demo: review pending invitations'**
  String get demoAlertTitle1;

  /// No description provided for @demoAlertTitle2.
  ///
  /// In en, this message translates to:
  /// **'Demo: data-access review due'**
  String get demoAlertTitle2;

  /// No description provided for @demoAlertTitle3.
  ///
  /// In en, this message translates to:
  /// **'Demo: sample alert — high traffic'**
  String get demoAlertTitle3;

  /// No description provided for @demoAlertTitle4.
  ///
  /// In en, this message translates to:
  /// **'Demo: retention window expiring'**
  String get demoAlertTitle4;

  /// No description provided for @demoAlertTitle5.
  ///
  /// In en, this message translates to:
  /// **'Demo: review completed'**
  String get demoAlertTitle5;

  /// No description provided for @demoTaskTitle1.
  ///
  /// In en, this message translates to:
  /// **'Demo: draft response checklist'**
  String get demoTaskTitle1;

  /// No description provided for @demoTaskTitle2.
  ///
  /// In en, this message translates to:
  /// **'Demo: gather documents'**
  String get demoTaskTitle2;

  /// No description provided for @demoTaskTitle3.
  ///
  /// In en, this message translates to:
  /// **'Demo: review client notes'**
  String get demoTaskTitle3;

  /// No description provided for @demoTaskTitle4.
  ///
  /// In en, this message translates to:
  /// **'Demo: schedule follow-up'**
  String get demoTaskTitle4;

  /// No description provided for @demoTaskTitle5.
  ///
  /// In en, this message translates to:
  /// **'Demo: update matter timeline'**
  String get demoTaskTitle5;

  /// No description provided for @researchHeadline.
  ///
  /// In en, this message translates to:
  /// **'Research note — {title}'**
  String researchHeadline(String title);

  /// No description provided for @researchSummaryDoc.
  ///
  /// In en, this message translates to:
  /// **'Demo research note compiled from the synthetic corpus row \"{title}\" ({ref}). This is static demo copy generated for the demo corpus — not legal analysis.'**
  String researchSummaryDoc(String title, String ref);

  /// No description provided for @researchSummaryMatter.
  ///
  /// In en, this message translates to:
  /// **'Demo research note compiled from the synthetic corpus row \"{title}\" ({area}). This is static demo copy generated for the demo corpus — not legal analysis.'**
  String researchSummaryMatter(String title, String area);

  /// No description provided for @researchExcerptDoc.
  ///
  /// In en, this message translates to:
  /// **'Corpus excerpt: {type} metadata row, matter ref \"{ref}\".'**
  String researchExcerptDoc(String type, String ref);

  /// No description provided for @researchExcerptMatter.
  ///
  /// In en, this message translates to:
  /// **'Corpus excerpt: matter row, practice area \"{area}\".'**
  String researchExcerptMatter(String area);

  /// No description provided for @researchRelatedMatter.
  ///
  /// In en, this message translates to:
  /// **'related demo matter'**
  String get researchRelatedMatter;

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

  /// No description provided for @homeFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get homeFallbackName;

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

  /// No description provided for @activeCaseTime.
  ///
  /// In en, this message translates to:
  /// **'Today, 10:00 AM'**
  String get activeCaseTime;

  /// No description provided for @activeCaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Estate of H. Vance vs. City'**
  String get activeCaseTitle;

  /// No description provided for @activeCaseBody.
  ///
  /// In en, this message translates to:
  /// **'Hearing scheduled for preliminary injunction regarding property line dispute in district court.'**
  String get activeCaseBody;

  /// No description provided for @activeCaseAttorney.
  ///
  /// In en, this message translates to:
  /// **'Atty. R. Sterling'**
  String get activeCaseAttorney;

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

  /// No description provided for @signInErrorNotice.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in. Please check your credentials and try again.'**
  String get signInErrorNotice;

  /// No description provided for @validatorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validatorRequired;

  /// No description provided for @validatorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validatorEmailInvalid;

  /// No description provided for @validatorMinLength.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Must be at least 1 character.} other{Must be at least {count} characters.}}'**
  String validatorMinLength(int count);

  /// No description provided for @validatorMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get validatorMismatch;

  /// No description provided for @validatorPasswordLength.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Must be at least 1 character.} other{Must be at least {count} characters.}}'**
  String validatorPasswordLength(int count);

  /// No description provided for @validatorPasswordClasses.
  ///
  /// In en, this message translates to:
  /// **'Include at least 3 of 4: uppercase, lowercase, digit, symbol.'**
  String get validatorPasswordClasses;

  /// No description provided for @validatorPasswordEmail.
  ///
  /// In en, this message translates to:
  /// **'Don\'t include your email address in the password.'**
  String get validatorPasswordEmail;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// No description provided for @passwordStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// No description provided for @profileNavigation.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNavigation;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// No description provided for @profileAccountIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get profileAccountIdLabel;

  /// No description provided for @profileRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileRoleLabel;

  /// No description provided for @profileExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Session expires'**
  String get profileExpiresLabel;

  /// No description provided for @deleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountAction;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and removes you from every organization. It cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountAuditNote.
  ///
  /// In en, this message translates to:
  /// **'Your data is deleted; audit records of your activity are retained.'**
  String get deleteAccountAuditNote;

  /// No description provided for @deleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirmAction;

  /// No description provided for @profileSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get profileSessionExpired;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsNote.
  ///
  /// In en, this message translates to:
  /// **'Preferences are stored on this device. Notification delivery is planned for a later release.'**
  String get notificationsNote;

  /// No description provided for @notifAppointmentReminders.
  ///
  /// In en, this message translates to:
  /// **'Appointment reminders'**
  String get notifAppointmentReminders;

  /// No description provided for @notifActivityUpdates.
  ///
  /// In en, this message translates to:
  /// **'Activity updates'**
  String get notifActivityUpdates;

  /// No description provided for @notifSystemAlerts.
  ///
  /// In en, this message translates to:
  /// **'System alerts'**
  String get notifSystemAlerts;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @orgTitle.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get orgTitle;

  /// No description provided for @createOrgTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Organization'**
  String get createOrgTitle;

  /// No description provided for @createOrgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give your firm a name. You will become its first partner.'**
  String get createOrgSubtitle;

  /// No description provided for @orgNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization name'**
  String get orgNameLabel;

  /// No description provided for @orgNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sterling & Associates'**
  String get orgNamePlaceholder;

  /// No description provided for @createOrgButton.
  ///
  /// In en, this message translates to:
  /// **'Create Organization'**
  String get createOrgButton;

  /// No description provided for @rosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get rosterTitle;

  /// No description provided for @rosterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get rosterEmpty;

  /// No description provided for @orgSwitcherLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get orgSwitcherLabel;

  /// No description provided for @acceptInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInvitationTitle;

  /// No description provided for @acceptInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'Paste the one-time token your partner shared with you.'**
  String get acceptInvitationBody;

  /// No description provided for @acceptInvitationAction.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptInvitationAction;

  /// No description provided for @invitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation accepted.'**
  String get invitationAccepted;

  /// No description provided for @invitationAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'You joined the organization.'**
  String get invitationAcceptedBody;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @inviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMember;

  /// No description provided for @inviteEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite by email'**
  String get inviteEmailLabel;

  /// No description provided for @inviteRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Assign role'**
  String get inviteRoleLabel;

  /// No description provided for @inviteTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time token'**
  String get inviteTokenLabel;

  /// No description provided for @inviteSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get inviteSendButton;

  /// No description provided for @inviteTokenBody.
  ///
  /// In en, this message translates to:
  /// **'Share this one-time token with {email}. It cannot be shown again.'**
  String inviteTokenBody(String email);

  /// No description provided for @inviteTokenCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get inviteTokenCopy;

  /// No description provided for @inviteTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied to clipboard.'**
  String get inviteTokenCopied;

  /// No description provided for @inviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Copy invite link'**
  String get inviteShareLink;

  /// No description provided for @inviteShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied to clipboard.'**
  String get inviteShareLinkCopied;

  /// No description provided for @actionResendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Resend invitation'**
  String get actionResendInvitation;

  /// No description provided for @actionRevokeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Revoke invitation'**
  String get actionRevokeInvitation;

  /// No description provided for @invitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invitation revoked.'**
  String get invitationRevoked;

  /// No description provided for @inviteTokenResentBody.
  ///
  /// In en, this message translates to:
  /// **'A fresh one-time token for {email}. It cannot be shown again.'**
  String inviteTokenResentBody(String email);

  /// No description provided for @memberStatusInvited.
  ///
  /// In en, this message translates to:
  /// **'INVITED'**
  String get memberStatusInvited;

  /// No description provided for @memberStatusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get memberStatusActive;

  /// No description provided for @memberStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'SUSPENDED'**
  String get memberStatusSuspended;

  /// No description provided for @memberStatusRemoved.
  ///
  /// In en, this message translates to:
  /// **'REMOVED'**
  String get memberStatusRemoved;

  /// No description provided for @actionSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get actionSuspend;

  /// No description provided for @actionReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get actionReactivate;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @removeMemberConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member?'**
  String get removeMemberConfirmTitle;

  /// No description provided for @removeMemberConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this organization?'**
  String removeMemberConfirmBody(String name);

  /// No description provided for @removeMemberConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeMemberConfirmAction;

  /// No description provided for @platformAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform admin'**
  String get platformAdminTitle;

  /// No description provided for @platformAdminOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get platformAdminOrganizations;

  /// No description provided for @platformAdminMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get platformAdminMembers;

  /// No description provided for @platformAdminDeleteDemo.
  ///
  /// In en, this message translates to:
  /// **'Delete demo account'**
  String get platformAdminDeleteDemo;

  /// No description provided for @platformAdminDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete demo account?'**
  String get platformAdminDeleteConfirmTitle;

  /// No description provided for @platformAdminDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the demo account for {name}? This cannot be undone.'**
  String platformAdminDeleteConfirmBody(String name);

  /// No description provided for @platformAdminDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get platformAdminDeleteConfirmAction;

  /// No description provided for @platformAdminAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get platformAdminAudit;

  /// No description provided for @platformAdminAuditPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform activity'**
  String get platformAdminAuditPlatform;

  /// No description provided for @orgErrorDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to perform this action.'**
  String get orgErrorDenied;

  /// No description provided for @orgErrorDuplicateMember.
  ///
  /// In en, this message translates to:
  /// **'This person is already a member of the organization.'**
  String get orgErrorDuplicateMember;

  /// No description provided for @orgErrorLastPartner.
  ///
  /// In en, this message translates to:
  /// **'The organization must keep at least one active partner.'**
  String get orgErrorLastPartner;

  /// No description provided for @orgErrorInvalidRole.
  ///
  /// In en, this message translates to:
  /// **'This role cannot be assigned.'**
  String get orgErrorInvalidRole;

  /// No description provided for @orgErrorInvalidName.
  ///
  /// In en, this message translates to:
  /// **'The organization name cannot be empty.'**
  String get orgErrorInvalidName;

  /// No description provided for @orgErrorInvalidInvitation.
  ///
  /// In en, this message translates to:
  /// **'The invitation is invalid or expired.'**
  String get orgErrorInvalidInvitation;

  /// No description provided for @orgErrorProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is unavailable right now. Please try again.'**
  String get orgErrorProviderUnavailable;

  /// No description provided for @orgErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get orgErrorUnknown;

  /// No description provided for @actionInProgress.
  ///
  /// In en, this message translates to:
  /// **'An action is already in progress.'**
  String get actionInProgress;

  /// No description provided for @signUpCheckInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Your Inbox'**
  String get signUpCheckInboxTitle;

  /// No description provided for @signUpCheckInboxBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification link to your email. Open it to activate your account, then sign in.'**
  String get signUpCheckInboxBody;

  /// No description provided for @signUpCheckInboxAction.
  ///
  /// In en, this message translates to:
  /// **'Continue to Sign In'**
  String get signUpCheckInboxAction;

  /// No description provided for @bookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a Consultation'**
  String get bookingTitle;

  /// No description provided for @bookingLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — no consultation is actually booked or sent.'**
  String get bookingLocalOnlyNote;

  /// No description provided for @bookingNoPaymentNote.
  ///
  /// In en, this message translates to:
  /// **'No payment is taken at this step.'**
  String get bookingNoPaymentNote;

  /// No description provided for @bookingCategoryStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation type'**
  String get bookingCategoryStepTitle;

  /// No description provided for @bookingCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get bookingCategoryGeneral;

  /// No description provided for @bookingCategoryFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get bookingCategoryFollowUp;

  /// No description provided for @bookingCategoryUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get bookingCategoryUrgent;

  /// No description provided for @bookingTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic (optional)'**
  String get bookingTopicLabel;

  /// No description provided for @bookingTopicPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe your question'**
  String get bookingTopicPlaceholder;

  /// No description provided for @bookingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bookingContinue;

  /// No description provided for @bookingSelectDateTimeStep.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get bookingSelectDateTimeStep;

  /// No description provided for @bookingSlotsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No times available.'**
  String get bookingSlotsEmpty;

  /// No description provided for @bookingSlotsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load available times.'**
  String get bookingSlotsError;

  /// No description provided for @bookingDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min} other{{minutes} min}}'**
  String bookingDurationMinutes(int minutes);

  /// No description provided for @bookingReviewStep.
  ///
  /// In en, this message translates to:
  /// **'Review your booking'**
  String get bookingReviewStep;

  /// No description provided for @bookingSummaryType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get bookingSummaryType;

  /// No description provided for @bookingSummaryTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get bookingSummaryTopic;

  /// No description provided for @bookingSummaryTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get bookingSummaryTime;

  /// No description provided for @bookingSummaryNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get bookingSummaryNotSet;

  /// No description provided for @bookingEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get bookingEditCategory;

  /// No description provided for @bookingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get bookingConfirm;

  /// No description provided for @bookingConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to confirm. Please try again.'**
  String get bookingConfirmFailed;

  /// No description provided for @bookingSlotUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That time is no longer available. Choose another time.'**
  String get bookingSlotUnavailable;

  /// No description provided for @bookingChooseAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Choose another time'**
  String get bookingChooseAnotherTime;

  /// No description provided for @bookingSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get bookingSuccessTitle;

  /// No description provided for @bookingSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Reference: {referenceId}'**
  String bookingSuccessBody(String referenceId);

  /// No description provided for @bookingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get bookingDone;

  /// No description provided for @bookingEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a consultation'**
  String get bookingEntryTitle;

  /// No description provided for @bookingEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a consultation — development demo.'**
  String get bookingEntrySubtitle;

  /// No description provided for @bookingEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Schedule a consultation with an available attorney.'**
  String get bookingEntrySubtitleConfigured;

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Find an Attorney'**
  String get discoveryTitle;

  /// No description provided for @discoverySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or practice area'**
  String get discoverySearchHint;

  /// No description provided for @discoveryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discoveryFilterAll;

  /// No description provided for @discoveryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attorneys match your search.'**
  String get discoveryEmpty;

  /// No description provided for @discoveryError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load attorneys.'**
  String get discoveryError;

  /// No description provided for @discoveryLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic profiles only. No real attorneys are listed or contacted.'**
  String get discoveryLocalOnlyNote;

  /// No description provided for @discoveryEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Find an attorney'**
  String get discoveryEntryTitle;

  /// No description provided for @discoveryEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo attorney profiles — development demo.'**
  String get discoveryEntrySubtitle;

  /// No description provided for @bookingSummaryAttorney.
  ///
  /// In en, this message translates to:
  /// **'Attorney'**
  String get bookingSummaryAttorney;

  /// No description provided for @bookingAttorneyPrefill.
  ///
  /// In en, this message translates to:
  /// **'Booking with {name}'**
  String bookingAttorneyPrefill(String name);

  /// No description provided for @discoveryProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Attorney profile'**
  String get discoveryProfileTitle;

  /// No description provided for @discoveryProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Attorney not found.'**
  String get discoveryProfileNotFound;

  /// No description provided for @discoveryProfileBio.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get discoveryProfileBio;

  /// No description provided for @discoveryProfileBook.
  ///
  /// In en, this message translates to:
  /// **'Book with this attorney'**
  String get discoveryProfileBook;

  /// No description provided for @discoveryDirectoryNote.
  ///
  /// In en, this message translates to:
  /// **'Directory profiles are maintained by the platform administrator. No credential verification is performed.'**
  String get discoveryDirectoryNote;

  /// No description provided for @discoveryProfileSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get discoveryProfileSpecialties;

  /// No description provided for @discoveryProfileLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get discoveryProfileLanguages;

  /// No description provided for @discoveryProfileYears.
  ///
  /// In en, this message translates to:
  /// **'{years} years of experience'**
  String discoveryProfileYears(int years);

  /// No description provided for @attorneyStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get attorneyStatusActive;

  /// No description provided for @attorneyStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get attorneyStatusInactive;

  /// No description provided for @attorneyAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Attorney directory'**
  String get attorneyAdminTitle;

  /// No description provided for @attorneyAdminEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Attorney directory'**
  String get attorneyAdminEntryTitle;

  /// No description provided for @attorneyAdminEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and manage directory profiles.'**
  String get attorneyAdminEntrySubtitle;

  /// No description provided for @attorneyAdminCreate.
  ///
  /// In en, this message translates to:
  /// **'Add attorney'**
  String get attorneyAdminCreate;

  /// No description provided for @attorneyAdminEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit attorney'**
  String get attorneyAdminEditTitle;

  /// No description provided for @attorneyAdminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get attorneyAdminSave;

  /// No description provided for @attorneyAdminDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get attorneyAdminDeactivate;

  /// No description provided for @attorneyAdminDeactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate attorney?'**
  String get attorneyAdminDeactivateTitle;

  /// No description provided for @attorneyAdminDeactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {name}? The profile stays in the admin list but leaves the public directory.'**
  String attorneyAdminDeactivateBody(String name);

  /// No description provided for @attorneyAdminDeactivateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to deactivate the profile. Please try again.'**
  String get attorneyAdminDeactivateFailed;

  /// No description provided for @attorneyAdminEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attorney profiles yet.'**
  String get attorneyAdminEmpty;

  /// No description provided for @attorneyAdminError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load attorney profiles.'**
  String get attorneyAdminError;

  /// No description provided for @attorneyAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Profiles are maintained by the platform administrator. No credential verification is performed.'**
  String get attorneyAdminNote;

  /// No description provided for @attorneyAdminNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get attorneyAdminNameLabel;

  /// No description provided for @attorneyAdminHeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Headline (optional)'**
  String get attorneyAdminHeadlineLabel;

  /// No description provided for @attorneyAdminBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio (optional)'**
  String get attorneyAdminBioLabel;

  /// No description provided for @attorneyAdminSpecialtiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get attorneyAdminSpecialtiesLabel;

  /// No description provided for @attorneyAdminLanguagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Languages (optional)'**
  String get attorneyAdminLanguagesLabel;

  /// No description provided for @attorneyAdminLanguagesHint.
  ///
  /// In en, this message translates to:
  /// **'Comma separated, e.g. EN, AR'**
  String get attorneyAdminLanguagesHint;

  /// No description provided for @attorneyAdminCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get attorneyAdminCityLabel;

  /// No description provided for @attorneyAdminYearsLabel.
  ///
  /// In en, this message translates to:
  /// **'Years of experience (optional)'**
  String get attorneyAdminYearsLabel;

  /// No description provided for @attorneyAdminNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name.'**
  String get attorneyAdminNameRequired;

  /// No description provided for @attorneyAdminNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters.'**
  String get attorneyAdminNameTooShort;

  /// No description provided for @attorneyAdminYearsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 0 to 80.'**
  String get attorneyAdminYearsInvalid;

  /// No description provided for @attorneyAdminSpecialtyRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one specialty.'**
  String get attorneyAdminSpecialtyRequired;

  /// No description provided for @attorneyAdminSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the profile. Please try again.'**
  String get attorneyAdminSaveFailed;

  /// No description provided for @matterTitle.
  ///
  /// In en, this message translates to:
  /// **'Matters'**
  String get matterTitle;

  /// No description provided for @matterFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get matterFilterAll;

  /// No description provided for @matterStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get matterStatusOpen;

  /// No description provided for @matterStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get matterStatusActive;

  /// No description provided for @matterStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get matterStatusClosed;

  /// No description provided for @matterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matters match the filter.'**
  String get matterEmpty;

  /// No description provided for @matterError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load matters.'**
  String get matterError;

  /// No description provided for @matterLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic matters only. No real cases are listed.'**
  String get matterLocalOnlyNote;

  /// No description provided for @matterEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'My matters'**
  String get matterEntryTitle;

  /// No description provided for @matterEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo matter files — development demo.'**
  String get matterEntrySubtitle;

  /// No description provided for @matterEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Browse your matters and their case files.'**
  String get matterEntrySubtitleConfigured;

  /// No description provided for @matterDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Matter details'**
  String get matterDetailsTitle;

  /// No description provided for @matterDetailsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Matter not found.'**
  String get matterDetailsNotFound;

  /// No description provided for @matterDetailsPracticeArea.
  ///
  /// In en, this message translates to:
  /// **'Practice area'**
  String get matterDetailsPracticeArea;

  /// No description provided for @matterDetailsAssignedAttorney.
  ///
  /// In en, this message translates to:
  /// **'Assigned attorney'**
  String get matterDetailsAssignedAttorney;

  /// No description provided for @matterDetailsCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get matterDetailsCreated;

  /// No description provided for @matterCreateFab.
  ///
  /// In en, this message translates to:
  /// **'New matter'**
  String get matterCreateFab;

  /// No description provided for @matterCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create matter'**
  String get matterCreateTitle;

  /// No description provided for @matterCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get matterCreateTitleLabel;

  /// No description provided for @matterCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Generic demo wording — never a real client or case name'**
  String get matterCreateTitleHint;

  /// No description provided for @matterCreatePracticeAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Practice area'**
  String get matterCreatePracticeAreaLabel;

  /// No description provided for @matterCreateAssignedClientLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned client (optional)'**
  String get matterCreateAssignedClientLabel;

  /// No description provided for @matterCreateAssignedAttorneyLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned attorney (optional)'**
  String get matterCreateAssignedAttorneyLabel;

  /// No description provided for @matterCreateAssigneeNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get matterCreateAssigneeNone;

  /// No description provided for @matterCreateNoOrg.
  ///
  /// In en, this message translates to:
  /// **'No active organization is selected. Choose an organization from the org hub, then return here to create a matter.'**
  String get matterCreateNoOrg;

  /// No description provided for @matterCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create matter'**
  String get matterCreateSubmit;

  /// No description provided for @matterCreateSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Matter created'**
  String get matterCreateSuccessTitle;

  /// No description provided for @matterCreateSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Matter {id} was created.'**
  String matterCreateSuccessBody(String id);

  /// No description provided for @matterCreateSuccessNote.
  ///
  /// In en, this message translates to:
  /// **'You see it now because you created it. Others see it once it is assigned to them.'**
  String get matterCreateSuccessNote;

  /// No description provided for @matterCreateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get matterCreateDone;

  /// No description provided for @matterCreateErrorDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to create matters in this organization.'**
  String get matterCreateErrorDenied;

  /// No description provided for @matterCreateErrorOwnerForbidden.
  ///
  /// In en, this message translates to:
  /// **'The platform owner cannot be assigned to a matter.'**
  String get matterCreateErrorOwnerForbidden;

  /// No description provided for @matterCreateErrorAssigneeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The assigned member is not an active member of this organization.'**
  String get matterCreateErrorAssigneeInvalid;

  /// No description provided for @matterCreateErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'A matter title is required.'**
  String get matterCreateErrorValidation;

  /// No description provided for @matterCreateErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Matter creation is temporarily unavailable. Please try again.'**
  String get matterCreateErrorUnavailable;

  /// No description provided for @matterCreateErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the matter. Please try again.'**
  String get matterCreateErrorFailed;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get vaultTitle;

  /// No description provided for @vaultEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents are available.'**
  String get vaultEmpty;

  /// No description provided for @vaultError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load documents.'**
  String get vaultError;

  /// No description provided for @vaultLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic document metadata only. No real files are listed.'**
  String get vaultLocalOnlyNote;

  /// No description provided for @viewMatter.
  ///
  /// In en, this message translates to:
  /// **'View matter'**
  String get viewMatter;

  /// No description provided for @vaultEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Document vault'**
  String get vaultEntryTitle;

  /// No description provided for @vaultEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo document metadata — development demo.'**
  String get vaultEntrySubtitle;

  /// No description provided for @vaultEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Browse the documents filed in your matters.'**
  String get vaultEntrySubtitleConfigured;

  /// No description provided for @documentTypeContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get documentTypeContract;

  /// No description provided for @documentTypeBrief.
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get documentTypeBrief;

  /// No description provided for @documentTypeEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get documentTypeEvidence;

  /// No description provided for @documentTypeCorrespondence.
  ///
  /// In en, this message translates to:
  /// **'Correspondence'**
  String get documentTypeCorrespondence;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No message threads are available.'**
  String get messagesEmpty;

  /// No description provided for @messagesError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load message threads.'**
  String get messagesError;

  /// No description provided for @messagesLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic thread metadata only. No real messages are listed.'**
  String get messagesLocalOnlyNote;

  /// No description provided for @messagesEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesEntryTitle;

  /// No description provided for @messagesEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo message threads — development demo.'**
  String get messagesEntrySubtitle;

  /// No description provided for @messagesEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Browse your message threads.'**
  String get messagesEntrySubtitleConfigured;

  /// No description provided for @messagesMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No messages} =1{1 message} other{{count} messages}}'**
  String messagesMessageCount(int count);

  /// No description provided for @messageThreadDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Thread messages'**
  String get messageThreadDetailTitle;

  /// No description provided for @messagesDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages are available in this thread.'**
  String get messagesDetailEmpty;

  /// No description provided for @messagesDetailError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load messages.'**
  String get messagesDetailError;

  /// No description provided for @messageComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get messageComposerHint;

  /// No description provided for @messageSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messageSend;

  /// No description provided for @messageErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message is too long. The maximum is {max} characters.'**
  String messageErrorTooLong(int max);

  /// No description provided for @messageErrorDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to send messages on this thread.'**
  String get messageErrorDenied;

  /// No description provided for @messageErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sending is temporarily unavailable. Please try again.'**
  String get messageErrorUnavailable;

  /// No description provided for @messageErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the message. Please try again.'**
  String get messageErrorFailed;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchNoQuery.
  ///
  /// In en, this message translates to:
  /// **'Type a search term to find demo matters, documents, messages, or attorneys.'**
  String get searchNoQuery;

  /// No description provided for @searchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results match your search.'**
  String get searchEmpty;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Unable to run the search.'**
  String get searchError;

  /// No description provided for @searchPartialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Some sources were unavailable — results may be incomplete.'**
  String get searchPartialUnavailable;

  /// No description provided for @searchLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — results come from synthetic lists only. No real data is searched.'**
  String get searchLocalOnlyNote;

  /// No description provided for @matterWorkspaceDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get matterWorkspaceDocumentsTitle;

  /// No description provided for @matterWorkspaceDocumentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents are available for this matter.'**
  String get matterWorkspaceDocumentsEmpty;

  /// No description provided for @matterWorkspaceMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get matterWorkspaceMessagesTitle;

  /// No description provided for @matterWorkspaceMessagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No message threads are available for this matter.'**
  String get matterWorkspaceMessagesEmpty;

  /// No description provided for @matterWorkspaceFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get matterWorkspaceFilesTitle;

  /// No description provided for @matterWorkspaceFilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files are available for this matter.'**
  String get matterWorkspaceFilesEmpty;

  /// No description provided for @filesError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load files.'**
  String get filesError;

  /// No description provided for @fileUploadAction.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get fileUploadAction;

  /// No description provided for @fileUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {fileName}…'**
  String fileUploading(String fileName);

  /// No description provided for @fileUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'File uploaded.'**
  String get fileUploadSuccess;

  /// No description provided for @fileUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to upload the file. Please try again.'**
  String get fileUploadFailed;

  /// No description provided for @fileUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large. The maximum size is 25 MB.'**
  String get fileUploadTooLarge;

  /// No description provided for @fileUploadUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported.'**
  String get fileUploadUnsupportedType;

  /// No description provided for @fileUploadDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to upload files to this matter.'**
  String get fileUploadDenied;

  /// No description provided for @fileOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fileOpenAction;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the file. Please try again.'**
  String get fileOpenFailed;

  /// No description provided for @fileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String fileSizeMb(String value);

  /// No description provided for @fileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String fileSizeKb(String value);

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String fileSizeBytes(String value);

  /// No description provided for @matterWorkspaceInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get matterWorkspaceInvoicesTitle;

  /// No description provided for @matterWorkspaceInvoicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invoices are available for this matter.'**
  String get matterWorkspaceInvoicesEmpty;

  /// No description provided for @invoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesTitle;

  /// No description provided for @invoicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invoices are available.'**
  String get invoicesEmpty;

  /// No description provided for @invoicesError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load invoices.'**
  String get invoicesError;

  /// No description provided for @invoicesLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic invoice metadata only. No real payments are shown.'**
  String get invoicesLocalOnlyNote;

  /// No description provided for @invoicesEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get invoicesEntryTitle;

  /// No description provided for @invoicesEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo invoice metadata — development demo.'**
  String get invoicesEntrySubtitle;

  /// No description provided for @invoicesEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Browse invoices and their payment status.'**
  String get invoicesEntrySubtitleConfigured;

  /// No description provided for @invoiceStatusIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get invoiceStatusIssued;

  /// No description provided for @invoiceStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoiceStatusPaid;

  /// No description provided for @invoicePayAction.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get invoicePayAction;

  /// No description provided for @paymentSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice payment'**
  String get paymentSheetTitle;

  /// No description provided for @paymentPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing secure checkout…'**
  String get paymentPreparing;

  /// No description provided for @paymentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment confirmation…'**
  String get paymentWaiting;

  /// No description provided for @paymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paymentSuccessTitle;

  /// No description provided for @paymentSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment was confirmed. The invoice will be marked as paid.'**
  String get paymentSuccessBody;

  /// No description provided for @paymentDemoSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Demo payment simulated — no charge was made and the invoice is unchanged.'**
  String get paymentDemoSuccessBody;

  /// No description provided for @paymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailedTitle;

  /// No description provided for @paymentFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The payment did not go through. You can try again.'**
  String get paymentFailedBody;

  /// No description provided for @paymentCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelledTitle;

  /// No description provided for @paymentCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The payment was cancelled. You can try again.'**
  String get paymentCancelledBody;

  /// No description provided for @paymentExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment expired'**
  String get paymentExpiredTitle;

  /// No description provided for @paymentExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'The checkout session expired. You can start a new payment.'**
  String get paymentExpiredBody;

  /// No description provided for @paymentCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get paymentCheckStatus;

  /// No description provided for @paymentRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paymentRetry;

  /// No description provided for @paymentClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paymentClose;

  /// No description provided for @paymentOpenCheckout.
  ///
  /// In en, this message translates to:
  /// **'Open checkout'**
  String get paymentOpenCheckout;

  /// No description provided for @paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payments are unavailable right now. Please try again.'**
  String get paymentUnavailable;

  /// No description provided for @paymentDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Demo only — no real charge.'**
  String get paymentDemoNote;

  /// No description provided for @paymentHostedCheckoutNote.
  ///
  /// In en, this message translates to:
  /// **'Complete the payment in the secure hosted checkout, then come back to this screen.'**
  String get paymentHostedCheckoutNote;

  /// No description provided for @paymentDemoSuccess.
  ///
  /// In en, this message translates to:
  /// **'Simulate success'**
  String get paymentDemoSuccess;

  /// No description provided for @paymentDemoFailure.
  ///
  /// In en, this message translates to:
  /// **'Simulate failure'**
  String get paymentDemoFailure;

  /// No description provided for @paymentDemoCancel.
  ///
  /// In en, this message translates to:
  /// **'Simulate cancel'**
  String get paymentDemoCancel;

  /// No description provided for @orgAuditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit trail'**
  String get orgAuditTitle;

  /// No description provided for @orgAuditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No audit events recorded yet.'**
  String get orgAuditEmpty;

  /// No description provided for @orgAuditNoOrganization.
  ///
  /// In en, this message translates to:
  /// **'No organization selected.'**
  String get orgAuditNoOrganization;

  /// No description provided for @orgAuditDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this organization\'s audit trail.'**
  String get orgAuditDenied;

  /// No description provided for @orgAuditError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the audit trail.'**
  String get orgAuditError;

  /// No description provided for @orgAuditRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get orgAuditRetry;

  /// No description provided for @orgAuditHubEntry.
  ///
  /// In en, this message translates to:
  /// **'View audit trail'**
  String get orgAuditHubEntry;

  /// No description provided for @orgAuditOutcomeAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get orgAuditOutcomeAllowed;

  /// No description provided for @orgAuditOutcomeDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get orgAuditOutcomeDenied;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance alerts'**
  String get alertsTitle;

  /// No description provided for @alertsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load compliance alerts.'**
  String get alertsError;

  /// No description provided for @alertsLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic alerts only. No real compliance event is shown.'**
  String get alertsLocalOnlyNote;

  /// No description provided for @alertsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance alerts'**
  String get alertsEntryTitle;

  /// No description provided for @alertsEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo alerts — development demo.'**
  String get alertsEntrySubtitle;

  /// No description provided for @alertsEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Review organization compliance alerts.'**
  String get alertsEntrySubtitleConfigured;

  /// No description provided for @alertsStoredNote.
  ///
  /// In en, this message translates to:
  /// **'Alerts are recorded for this organization. No automated legal verification is performed.'**
  String get alertsStoredNote;

  /// No description provided for @alertsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No alerts match this filter.'**
  String get alertsEmptyFiltered;

  /// No description provided for @alertsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get alertsFilterAll;

  /// No description provided for @alertsCreateFab.
  ///
  /// In en, this message translates to:
  /// **'New alert'**
  String get alertsCreateFab;

  /// No description provided for @alertStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get alertStatusOpen;

  /// No description provided for @alertStatusAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get alertStatusAcknowledged;

  /// No description provided for @alertStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get alertStatusResolved;

  /// No description provided for @alertKindDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get alertKindDeadline;

  /// No description provided for @alertKindConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict check'**
  String get alertKindConflict;

  /// No description provided for @alertKindRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get alertKindRetention;

  /// No description provided for @alertKindFiling.
  ///
  /// In en, this message translates to:
  /// **'Filing'**
  String get alertKindFiling;

  /// No description provided for @alertKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get alertKindOther;

  /// No description provided for @alertSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get alertSeverityLow;

  /// No description provided for @alertSeverityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get alertSeverityMedium;

  /// No description provided for @alertSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get alertSeverityHigh;

  /// No description provided for @alertSeverityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get alertSeverityCritical;

  /// No description provided for @alertCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New compliance alert'**
  String get alertCreateTitle;

  /// No description provided for @alertCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get alertCreateTitleLabel;

  /// No description provided for @alertCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Filing deadline review'**
  String get alertCreateTitleHint;

  /// No description provided for @alertCreateTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 2 characters.'**
  String get alertCreateTitleTooShort;

  /// No description provided for @alertCreateTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title must be 160 characters or fewer.'**
  String get alertCreateTitleTooLong;

  /// No description provided for @alertCreateKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get alertCreateKindLabel;

  /// No description provided for @alertCreateSeverityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get alertCreateSeverityLabel;

  /// No description provided for @alertCreateDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get alertCreateDescriptionLabel;

  /// No description provided for @alertCreateDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description must be 4000 characters or fewer.'**
  String get alertCreateDescriptionTooLong;

  /// No description provided for @alertCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create alert'**
  String get alertCreateSubmit;

  /// No description provided for @alertCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Alert created.'**
  String get alertCreateSuccess;

  /// No description provided for @alertCreateNoOrg.
  ///
  /// In en, this message translates to:
  /// **'Select an organization before creating an alert.'**
  String get alertCreateNoOrg;

  /// No description provided for @alertDetailKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get alertDetailKind;

  /// No description provided for @alertDetailSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get alertDetailSeverity;

  /// No description provided for @alertDetailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get alertDetailCreated;

  /// No description provided for @alertDetailDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get alertDetailDue;

  /// No description provided for @alertDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get alertDetailDescription;

  /// No description provided for @alertDetailAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get alertDetailAcknowledged;

  /// No description provided for @alertDetailResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get alertDetailResolved;

  /// No description provided for @alertAcknowledgeAction.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge alert'**
  String get alertAcknowledgeAction;

  /// No description provided for @alertResolveAction.
  ///
  /// In en, this message translates to:
  /// **'Resolve alert'**
  String get alertResolveAction;

  /// No description provided for @alertResolveNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get alertResolveNoteLabel;

  /// No description provided for @alertAcknowledgedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Alert acknowledged.'**
  String get alertAcknowledgedSuccess;

  /// No description provided for @alertResolvedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Alert resolved.'**
  String get alertResolvedSuccess;

  /// No description provided for @alertErrorDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get alertErrorDenied;

  /// No description provided for @alertErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again.'**
  String get alertErrorUnavailable;

  /// No description provided for @alertErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The alert can no longer be updated. Refresh and try again.'**
  String get alertErrorInvalid;

  /// No description provided for @alertErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get alertErrorFailed;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Task board'**
  String get tasksTitle;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks are available.'**
  String get tasksEmpty;

  /// No description provided for @tasksError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load tasks.'**
  String get tasksError;

  /// No description provided for @tasksLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic tasks only. No real case work is listed.'**
  String get tasksLocalOnlyNote;

  /// No description provided for @tasksEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Task board'**
  String get tasksEntryTitle;

  /// No description provided for @tasksEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo tasks — development demo.'**
  String get tasksEntrySubtitle;

  /// No description provided for @tasksEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Browse the tasks assigned to you.'**
  String get tasksEntrySubtitleConfigured;

  /// No description provided for @taskStatusTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get taskStatusTodo;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskStatusBlocked;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get taskAcknowledge;

  /// No description provided for @taskAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get taskAcknowledged;

  /// Button label that opens the create-task sheet from the task board header.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskCreateAction;

  /// Title of the create-task bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskCreateTitle;

  /// Label above the task title field in the create-task sheet.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskCreateTitleLabel;

  /// Placeholder example for the task title field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Draft response checklist'**
  String get taskCreateTitleHint;

  /// Label for the matter dropdown in the create-task sheet.
  ///
  /// In en, this message translates to:
  /// **'Matter'**
  String get taskCreateMatterLabel;

  /// Placeholder shown when no matter is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a matter'**
  String get taskCreateMatterHint;

  /// Submit button of the create-task sheet.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get taskCreateSubmit;

  /// Honest empty state when the matter list is empty.
  ///
  /// In en, this message translates to:
  /// **'No matters are available to create a task on.'**
  String get taskCreateNoMatters;

  /// Inline error when the matter list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Unable to load matters. Please try again.'**
  String get taskCreateMattersError;

  /// Tooltip of a task row's assign button.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get taskAssignAction;

  /// Title of the assign-task bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Assign task'**
  String get taskAssignTitle;

  /// Label for the assignee dropdown in the assign-task sheet.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get taskAssignMemberLabel;

  /// Dropdown option that clears the task assignee.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskAssignUnassigned;

  /// Submit button of the assign-task sheet.
  ///
  /// In en, this message translates to:
  /// **'Save assignment'**
  String get taskAssignSubmit;

  /// Inline error when the assignable roster fails to load.
  ///
  /// In en, this message translates to:
  /// **'Unable to load members. Please try again.'**
  String get taskAssignMembersError;

  /// Neutral row shown when the task's current assignee is not in the active roster.
  ///
  /// In en, this message translates to:
  /// **'Current assignee unavailable'**
  String get taskAssigneeUnavailable;

  /// Localized task action denial.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get taskErrorDenied;

  /// Localized task action outage.
  ///
  /// In en, this message translates to:
  /// **'This is temporarily unavailable. Please try again.'**
  String get taskErrorUnavailable;

  /// Localized task action validation refusal.
  ///
  /// In en, this message translates to:
  /// **'That change is not valid. Check the details and try again.'**
  String get taskErrorInvalid;

  /// Localized generic task action failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get taskErrorFailed;

  /// No description provided for @approvalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get approvalsTitle;

  /// No description provided for @approvalsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load approvals.'**
  String get approvalsError;

  /// No description provided for @approvalsLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic redacted rows only. No real approval is pending.'**
  String get approvalsLocalOnlyNote;

  /// No description provided for @approvalsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get approvalsEntryTitle;

  /// No description provided for @approvalsEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse demo approvals — development demo.'**
  String get approvalsEntrySubtitle;

  /// No description provided for @approvalsEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Review organization approval requests.'**
  String get approvalsEntrySubtitleConfigured;

  /// No description provided for @approvalStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get approvalStatusPending;

  /// No description provided for @approvalStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvalStatusApproved;

  /// No description provided for @approvalStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get approvalStatusDenied;

  /// No description provided for @approvalStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get approvalStatusCancelled;

  /// No description provided for @approvalsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvalsScreenTitle;

  /// No description provided for @approvalsStoredNote.
  ///
  /// In en, this message translates to:
  /// **'Requests are stored for this organization.'**
  String get approvalsStoredNote;

  /// No description provided for @approvalsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No approvals match this filter.'**
  String get approvalsEmptyFiltered;

  /// No description provided for @approvalsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get approvalsFilterAll;

  /// No description provided for @approvalsCreateFab.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get approvalsCreateFab;

  /// No description provided for @approvalKindConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict check'**
  String get approvalKindConflict;

  /// No description provided for @approvalKindWaiver.
  ///
  /// In en, this message translates to:
  /// **'Waiver'**
  String get approvalKindWaiver;

  /// No description provided for @approvalKindFiling.
  ///
  /// In en, this message translates to:
  /// **'Filing'**
  String get approvalKindFiling;

  /// No description provided for @approvalKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get approvalKindExpense;

  /// No description provided for @approvalKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get approvalKindOther;

  /// No description provided for @approvalCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New approval request'**
  String get approvalCreateTitle;

  /// No description provided for @approvalCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get approvalCreateTitleLabel;

  /// No description provided for @approvalCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Conflict waiver for a new matter'**
  String get approvalCreateTitleHint;

  /// No description provided for @approvalCreateTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 2 characters.'**
  String get approvalCreateTitleTooShort;

  /// No description provided for @approvalCreateTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title must be 160 characters or fewer.'**
  String get approvalCreateTitleTooLong;

  /// No description provided for @approvalCreateKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get approvalCreateKindLabel;

  /// No description provided for @approvalCreateMatterLabel.
  ///
  /// In en, this message translates to:
  /// **'Matter (optional)'**
  String get approvalCreateMatterLabel;

  /// No description provided for @approvalCreateMatterNone.
  ///
  /// In en, this message translates to:
  /// **'No matter'**
  String get approvalCreateMatterNone;

  /// No description provided for @approvalCreateMattersError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load matters. You can still submit without a matter.'**
  String get approvalCreateMattersError;

  /// No description provided for @approvalCreateDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get approvalCreateDescriptionLabel;

  /// No description provided for @approvalCreateDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description must be 4000 characters or fewer.'**
  String get approvalCreateDescriptionTooLong;

  /// No description provided for @approvalCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get approvalCreateSubmit;

  /// No description provided for @approvalCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request submitted.'**
  String get approvalCreateSuccess;

  /// No description provided for @approvalCreateNoOrg.
  ///
  /// In en, this message translates to:
  /// **'Select an organization before creating a request.'**
  String get approvalCreateNoOrg;

  /// No description provided for @approvalDetailKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get approvalDetailKind;

  /// No description provided for @approvalDetailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get approvalDetailCreated;

  /// No description provided for @approvalDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get approvalDetailDescription;

  /// No description provided for @approvalDetailDecided.
  ///
  /// In en, this message translates to:
  /// **'Decided'**
  String get approvalDetailDecided;

  /// No description provided for @approvalDetailDecisionNote.
  ///
  /// In en, this message translates to:
  /// **'Decision note'**
  String get approvalDetailDecisionNote;

  /// No description provided for @approvalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvalApprove;

  /// No description provided for @approvalReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get approvalReject;

  /// No description provided for @approvalDecideNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (required to reject)'**
  String get approvalDecideNoteLabel;

  /// No description provided for @approvalRejectNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a note of at least 2 characters to reject.'**
  String get approvalRejectNoteRequired;

  /// No description provided for @approvalCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get approvalCancelAction;

  /// No description provided for @approvalCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get approvalCancelConfirmTitle;

  /// No description provided for @approvalCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The request will be marked as cancelled. This cannot be undone.'**
  String get approvalCancelConfirmBody;

  /// No description provided for @approvalDecidedApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved.'**
  String get approvalDecidedApproved;

  /// No description provided for @approvalDecidedRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected.'**
  String get approvalDecidedRejected;

  /// No description provided for @approvalCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get approvalCancelled;

  /// No description provided for @approvalErrorDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get approvalErrorDenied;

  /// No description provided for @approvalErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again.'**
  String get approvalErrorUnavailable;

  /// No description provided for @approvalErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The request can no longer be updated. Refresh and try again.'**
  String get approvalErrorInvalid;

  /// No description provided for @approvalErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get approvalErrorFailed;

  /// No description provided for @notificationsFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification feed'**
  String get notificationsFeedTitle;

  /// No description provided for @notificationsFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications are available.'**
  String get notificationsFeedEmpty;

  /// No description provided for @notificationsFeedError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load notifications.'**
  String get notificationsFeedError;

  /// No description provided for @notificationsFeedLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic notification metadata only. No push or delivery is shown.'**
  String get notificationsFeedLocalOnlyNote;

  /// No description provided for @notificationsFeedEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification feed'**
  String get notificationsFeedEntryTitle;

  /// No description provided for @notificationsFeedEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View org activity alerts — read-only demo feed.'**
  String get notificationsFeedEntrySubtitle;

  /// No description provided for @notificationsFeedEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'View your organization\'s activity alerts.'**
  String get notificationsFeedEntrySubtitleConfigured;

  /// No description provided for @notificationCategoryAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get notificationCategoryAppointment;

  /// No description provided for @notificationCategoryActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get notificationCategoryActivity;

  /// No description provided for @notificationCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationCategorySystem;

  /// No description provided for @aiResearchTitle.
  ///
  /// In en, this message translates to:
  /// **'AI research'**
  String get aiResearchTitle;

  /// No description provided for @aiResearchAdvisoryBanner.
  ///
  /// In en, this message translates to:
  /// **'AI-suggested — not legal advice. Demo research over synthetic demo data only.'**
  String get aiResearchAdvisoryBanner;

  /// No description provided for @aiResearchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a research question…'**
  String get aiResearchFieldHint;

  /// No description provided for @aiResearchIdlePrompt.
  ///
  /// In en, this message translates to:
  /// **'Ask a question to search the demo research corpus.'**
  String get aiResearchIdlePrompt;

  /// No description provided for @aiResearchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches in the demo corpus. Try different words.'**
  String get aiResearchNoMatches;

  /// No description provided for @aiResearchError.
  ///
  /// In en, this message translates to:
  /// **'Unable to run the research query.'**
  String get aiResearchError;

  /// No description provided for @aiResearchLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — synthetic findings with citations only. Nothing is stored or sent.'**
  String get aiResearchLocalOnlyNote;

  /// No description provided for @aiResearchCitationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get aiResearchCitationsLabel;

  /// No description provided for @aiResearchEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI research'**
  String get aiResearchEntryTitle;

  /// No description provided for @aiResearchEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask the demo research assistant — advisory only.'**
  String get aiResearchEntrySubtitle;

  /// No description provided for @notificationsFeedUnreadSemantics.
  ///
  /// In en, this message translates to:
  /// **'Unread notification. Tap to mark as read.'**
  String get notificationsFeedUnreadSemantics;

  /// No description provided for @notificationsFeedMutedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Notifications are muted in your notification settings.'**
  String get notificationsFeedMutedEmpty;

  /// No description provided for @videoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video consultations'**
  String get videoTitle;

  /// No description provided for @videoEmpty.
  ///
  /// In en, this message translates to:
  /// **'No video consultations yet.'**
  String get videoEmpty;

  /// No description provided for @videoError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load video consultations.'**
  String get videoError;

  /// No description provided for @videoLocalOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — sample sessions only. Video calls require a configured deployment.'**
  String get videoLocalOnlyNote;

  /// No description provided for @videoEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Video consultation'**
  String get videoEntryTitle;

  /// No description provided for @videoEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule or join a video consultation.'**
  String get videoEntrySubtitle;

  /// No description provided for @videoEntrySubtitleConfigured.
  ///
  /// In en, this message translates to:
  /// **'Schedule or join a video consultation with your legal team.'**
  String get videoEntrySubtitleConfigured;

  /// No description provided for @videoJoin.
  ///
  /// In en, this message translates to:
  /// **'Join call'**
  String get videoJoin;

  /// No description provided for @videoCallElapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed {duration}'**
  String videoCallElapsed(String duration);

  /// No description provided for @videoCallYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get videoCallYou;

  /// No description provided for @videoMicOn.
  ///
  /// In en, this message translates to:
  /// **'Mute microphone'**
  String get videoMicOn;

  /// No description provided for @videoMicMuted.
  ///
  /// In en, this message translates to:
  /// **'Unmute microphone'**
  String get videoMicMuted;

  /// No description provided for @videoCameraOn.
  ///
  /// In en, this message translates to:
  /// **'Turn camera off'**
  String get videoCameraOn;

  /// No description provided for @videoCameraOff.
  ///
  /// In en, this message translates to:
  /// **'Turn camera on'**
  String get videoCameraOff;

  /// No description provided for @videoLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave call'**
  String get videoLeave;

  /// No description provided for @videoStoredNote.
  ///
  /// In en, this message translates to:
  /// **'Video consultations are stored with your organization. Calls use LiveKit; nothing is recorded.'**
  String get videoStoredNote;

  /// No description provided for @videoCreateFab.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get videoCreateFab;

  /// No description provided for @videoCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a video consultation'**
  String get videoCreateTitle;

  /// No description provided for @videoCreateMatterLabel.
  ///
  /// In en, this message translates to:
  /// **'Matter (optional)'**
  String get videoCreateMatterLabel;

  /// No description provided for @videoCreateMatterNone.
  ///
  /// In en, this message translates to:
  /// **'No matter'**
  String get videoCreateMatterNone;

  /// No description provided for @videoCreateMattersError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load matters.'**
  String get videoCreateMattersError;

  /// No description provided for @videoCreateDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get videoCreateDateLabel;

  /// No description provided for @videoCreateDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a date and time for the session.'**
  String get videoCreateDateRequired;

  /// No description provided for @videoCreateNoOrg.
  ///
  /// In en, this message translates to:
  /// **'Select an organization before scheduling a session.'**
  String get videoCreateNoOrg;

  /// No description provided for @videoCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Schedule session'**
  String get videoCreateSubmit;

  /// No description provided for @videoCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Video consultation scheduled.'**
  String get videoCreateSuccess;

  /// No description provided for @videoEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get videoEnd;

  /// No description provided for @videoEndConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End this consultation?'**
  String get videoEndConfirmTitle;

  /// No description provided for @videoEndConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone will be disconnected and the session will be marked ended.'**
  String get videoEndConfirmBody;

  /// No description provided for @videoEndConfirm.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get videoEndConfirm;

  /// No description provided for @videoEndSuccess.
  ///
  /// In en, this message translates to:
  /// **'Video consultation ended.'**
  String get videoEndSuccess;

  /// No description provided for @videoStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get videoStatusScheduled;

  /// No description provided for @videoStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get videoStatusLive;

  /// No description provided for @videoStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get videoStatusEnded;

  /// No description provided for @videoStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get videoStatusCancelled;

  /// No description provided for @videoSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Video consultation'**
  String get videoSessionTitle;

  /// No description provided for @videoProviderNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Video calls are not configured for this deployment. No call was started.'**
  String get videoProviderNotConfigured;

  /// No description provided for @videoJoinUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Call unavailable'**
  String get videoJoinUnavailableTitle;

  /// No description provided for @videoErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to use video consultations.'**
  String get videoErrorUnauthorized;

  /// No description provided for @videoErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get videoErrorForbidden;

  /// No description provided for @videoErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This video consultation was not found.'**
  String get videoErrorNotFound;

  /// No description provided for @videoErrorEnded.
  ///
  /// In en, this message translates to:
  /// **'This video consultation has already ended.'**
  String get videoErrorEnded;

  /// No description provided for @videoErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the session details and try again.'**
  String get videoErrorInvalid;

  /// No description provided for @videoErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video calls are temporarily unavailable. Please try again.'**
  String get videoErrorUnavailable;

  /// No description provided for @videoErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete that action. Please try again.'**
  String get videoErrorFailed;

  /// No description provided for @videoNoOrg.
  ///
  /// In en, this message translates to:
  /// **'Select an organization to view video consultations.'**
  String get videoNoOrg;

  /// No description provided for @videoCallConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get videoCallConnecting;

  /// No description provided for @videoCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the call.'**
  String get videoCallFailed;

  /// No description provided for @videoCallMediaWarning.
  ///
  /// In en, this message translates to:
  /// **'Connected, but the camera or microphone could not be enabled.'**
  String get videoCallMediaWarning;

  /// No description provided for @unmatchedRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'This link could not be opened.'**
  String get unmatchedRouteTitle;

  /// No description provided for @aiResearchQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Research question'**
  String get aiResearchQuestionLabel;

  /// No description provided for @aiResearchQuestionTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 2 characters.'**
  String get aiResearchQuestionTooShort;

  /// No description provided for @aiResearchQuestionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the question at 500 characters or fewer.'**
  String get aiResearchQuestionTooLong;

  /// No description provided for @aiResearchMatterLabel.
  ///
  /// In en, this message translates to:
  /// **'Matter (optional)'**
  String get aiResearchMatterLabel;

  /// No description provided for @aiResearchMatterNone.
  ///
  /// In en, this message translates to:
  /// **'No matter'**
  String get aiResearchMatterNone;

  /// No description provided for @aiResearchMattersError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load matters.'**
  String get aiResearchMattersError;

  /// No description provided for @aiResearchDocumentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Documents (optional)'**
  String get aiResearchDocumentsLabel;

  /// No description provided for @aiResearchDocumentsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load documents.'**
  String get aiResearchDocumentsError;

  /// No description provided for @aiResearchDocumentsNone.
  ///
  /// In en, this message translates to:
  /// **'No documents available.'**
  String get aiResearchDocumentsNone;

  /// No description provided for @aiResearchReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get aiResearchReload;

  /// No description provided for @aiResearchGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate findings'**
  String get aiResearchGenerate;

  /// No description provided for @aiResearchRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent research runs'**
  String get aiResearchRunsTitle;

  /// No description provided for @aiResearchRunsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No research runs yet.'**
  String get aiResearchRunsEmpty;

  /// No description provided for @aiResearchRunsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load run history.'**
  String get aiResearchRunsError;

  /// No description provided for @aiResearchRunStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get aiResearchRunStatusRunning;

  /// No description provided for @aiResearchRunStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get aiResearchRunStatusCompleted;

  /// No description provided for @aiResearchRunStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get aiResearchRunStatusFailed;

  /// No description provided for @aiResearchProviderNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'AI research is not configured for this deployment. No analysis was run.'**
  String get aiResearchProviderNotConfigured;

  /// No description provided for @aiResearchGeneratedNotice.
  ///
  /// In en, this message translates to:
  /// **'AI-generated — review before relying on it. Not legal advice.'**
  String get aiResearchGeneratedNotice;

  /// No description provided for @aiResearchStoredNote.
  ///
  /// In en, this message translates to:
  /// **'AI-generated findings are stored with your organization.'**
  String get aiResearchStoredNote;

  /// No description provided for @aiResearchIdlePromptReal.
  ///
  /// In en, this message translates to:
  /// **'Ask a question across the selected matter and documents.'**
  String get aiResearchIdlePromptReal;

  /// No description provided for @aiResearchErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to use AI research.'**
  String get aiResearchErrorUnauthorized;

  /// No description provided for @aiResearchErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot run AI research.'**
  String get aiResearchErrorForbidden;

  /// No description provided for @aiResearchErrorInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Check the question and selected items, then try again.'**
  String get aiResearchErrorInvalidRequest;

  /// No description provided for @aiResearchErrorContextTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The selected context is too large. Remove documents and try again.'**
  String get aiResearchErrorContextTooLarge;

  /// No description provided for @aiResearchErrorProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI provider is temporarily unavailable. Please try again.'**
  String get aiResearchErrorProviderUnavailable;

  /// No description provided for @aiResearchErrorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The AI provider returned an unexpected response. Please try again.'**
  String get aiResearchErrorInvalidResponse;

  /// No description provided for @aiResearchErrorNoOrg.
  ///
  /// In en, this message translates to:
  /// **'Select an organization to run research.'**
  String get aiResearchErrorNoOrg;

  /// No description provided for @aiResearchNoSourceCited.
  ///
  /// In en, this message translates to:
  /// **'No source cited.'**
  String get aiResearchNoSourceCited;

  /// No description provided for @aiResearchSourceDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get aiResearchSourceDocument;

  /// No description provided for @aiResearchSourceMatter.
  ///
  /// In en, this message translates to:
  /// **'Matter'**
  String get aiResearchSourceMatter;
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
