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

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @resendCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Resend Code (unavailable in demo)'**
  String get resendCodeUnavailable;

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
  /// **'Must be at least {count} characters.'**
  String validatorMinLength(int count);

  /// No description provided for @validatorMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get validatorMismatch;

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
  /// **'{minutes} min'**
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

  /// No description provided for @messagesMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String messagesMessageCount(Object count);

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
