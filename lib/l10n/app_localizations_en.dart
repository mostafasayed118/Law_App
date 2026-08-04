// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LegalHub';

  @override
  String get accessTitle => 'Access the foundation';

  @override
  String get accessBody =>
      'This bootstrap uses a local demo session only. No credentials are collected or sent.';

  @override
  String get continueAsDemo => 'Continue with demo session';

  @override
  String get demoSessionNotice => 'Development-only demo session';

  @override
  String get homeTitle => 'Foundation workspace';

  @override
  String get homeBody =>
      'This placeholder proves the theme, localization, RTL wiring, and shared view states. No legal or client data is loaded.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get roleLabel => 'Placeholder role';

  @override
  String get roleClient => 'Client';

  @override
  String get roleAttorney => 'Attorney';

  @override
  String get rolePartner => 'Partner';

  @override
  String get roleComplianceOfficer => 'Compliance officer';

  @override
  String get roleResearchAnalyst => 'Research analyst';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get homeNavigation => 'Home';

  @override
  String get settingsNavigation => 'Settings';

  @override
  String get stateSuccess => 'Ready';

  @override
  String get stateEmpty => 'Nothing to show';

  @override
  String get stateError => 'Unable to load this placeholder';

  @override
  String get stateOffline => 'Offline';

  @override
  String get stateUnauthorized => 'Access not available';

  @override
  String get stateLoading => 'Loading';

  @override
  String get retry => 'Retry';

  @override
  String get foundationReady => 'Foundation ready';

  @override
  String get signOut => 'End demo session';

  @override
  String get back => 'Back';

  @override
  String get signInWelcome => 'Welcome Back';

  @override
  String get signInSubtitle =>
      'Sign in to access your secure legal workstation.';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get emailPlaceholder => 'e.g. counsel@firm.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordPlaceholder => '••••••••';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get signInButton => 'Sign In';

  @override
  String get orContinueWith => 'OR CONTINUE WITH';

  @override
  String get continueWithGoogle => 'Google';

  @override
  String get continueWithApple => 'Apple';

  @override
  String get newToLegalHub => 'New to LegalHub?';

  @override
  String get createAccount => 'Create an account';

  @override
  String get signUpTitle => 'Create Account';

  @override
  String get signUpSubtitle => 'Enter your details to register your practice.';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get fullNamePlaceholder => 'Jane Doe';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get phonePlaceholder => '+1 (555) 000-0000';

  @override
  String get passwordHint => 'Must be at least 8 characters.';

  @override
  String get agreeToTerms =>
      'I agree to the Terms & Conditions and Privacy Policy.';

  @override
  String get signUpButton => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signInLink => 'Sign In';

  @override
  String get recoverPasswordTitle => 'Recover Password';

  @override
  String get recoverPasswordBody =>
      'Enter your registered email address to receive a verification code.';

  @override
  String get sendCodeButton => 'Send Code';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get codeSentNotice => 'Verification code sent to your inbox.';

  @override
  String get verifyEmailTitle => 'Verify Email';

  @override
  String get verifyEmailBody =>
      'We\'ve sent a 6-digit code to your email address.';

  @override
  String get verifyAndContinueButton => 'Verify & Continue';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get resendCodeUnavailable => 'Resend Code (unavailable in demo)';

  @override
  String get resendHelp =>
      'Didn\'t receive the email? Check your spam folder or contact support.';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get resetSuccessNotice =>
      'Your password has been reset. You can sign in now.';

  @override
  String get onboardingTitle1 => 'Expert Legal Advice';

  @override
  String get onboardingDesc1 =>
      'Connect seamlessly with top-tier legal professionals. Unparalleled expertise tailored for your most critical and complex matters.';

  @override
  String get onboardingTitle2 => 'Case Tracking';

  @override
  String get onboardingDesc2 =>
      'Monitor your legal matters in real-time with precise updates. Stay informed at every procedural step with our structured timeline view.';

  @override
  String get onboardingTitle3 => 'Secure Communication';

  @override
  String get onboardingDesc3 =>
      'Confidential messaging utilizing state-of-the-art encryption protocols. Your attorney-client privilege, protected in the digital realm.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get skip => 'SKIP';

  @override
  String get onboardingSuccessTitle => 'You\'re All Set';

  @override
  String get onboardingSuccessBody =>
      'Your secure legal workstation is ready. Sign in to begin.';

  @override
  String get onboardingSuccessAction => 'Continue to Sign In';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeFallbackName => 'Guest';

  @override
  String get homeSubtitle =>
      'How can we assist you with your legal needs today?';

  @override
  String get searchPlaceholder => 'Find a lawyer or legal topic...';

  @override
  String get practiceAreas => 'Practice Areas';

  @override
  String get viewAll => 'VIEW ALL';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get areaCriminal => 'Criminal';

  @override
  String get areaCivil => 'Civil';

  @override
  String get areaCorporate => 'Corporate';

  @override
  String get areaFamily => 'Family';

  @override
  String get activeCaseChip => 'ACTIVE CASE';

  @override
  String get activeCaseTime => 'Today, 10:00 AM';

  @override
  String get activeCaseTitle => 'Estate of H. Vance vs. City';

  @override
  String get activeCaseBody =>
      'Hearing scheduled for preliminary injunction regarding property line dispute in district court.';

  @override
  String get activeCaseAttorney => 'Atty. R. Sterling';

  @override
  String get actionRequiredTitle => 'Action Required';

  @override
  String get actionRequiredBody => 'Signature needed for retainer agreement.';

  @override
  String get consultationTitle => 'Consultation';

  @override
  String get consultationBody => 'Tomorrow at 2:00 PM via Video Call.';

  @override
  String get signInErrorNotice =>
      'Unable to sign in. Please check your credentials and try again.';

  @override
  String get validatorRequired => 'This field is required.';

  @override
  String get validatorEmailInvalid => 'Enter a valid email address.';

  @override
  String validatorMinLength(int count) {
    return 'Must be at least $count characters.';
  }

  @override
  String get validatorMismatch => 'Passwords do not match.';

  @override
  String get casesNavigation => 'Cases';

  @override
  String get messagesNavigation => 'Messages';

  @override
  String get profileNavigation => 'Profile';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileAccountIdLabel => 'Account ID';

  @override
  String get profileRoleLabel => 'Role';

  @override
  String get profileExpiresLabel => 'Session expires';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get deleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmBody =>
      'This permanently deletes your account and removes you from every organization. It cannot be undone.';

  @override
  String get deleteAccountConfirmAction => 'Delete';

  @override
  String get profileSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsNote =>
      'Preferences are stored on this device. Notification delivery is planned for a later release.';

  @override
  String get notifAppointmentReminders => 'Appointment reminders';

  @override
  String get notifActivityUpdates => 'Activity updates';

  @override
  String get notifSystemAlerts => 'System alerts';

  @override
  String get cancel => 'Cancel';

  @override
  String get orgTitle => 'Organization';

  @override
  String get createOrgTitle => 'Create Organization';

  @override
  String get createOrgSubtitle =>
      'Give your firm a name. You will become its first partner.';

  @override
  String get orgNameLabel => 'Organization name';

  @override
  String get orgNamePlaceholder => 'e.g. Sterling & Associates';

  @override
  String get createOrgButton => 'Create Organization';

  @override
  String get rosterTitle => 'Members';

  @override
  String get rosterEmpty => 'No members yet.';

  @override
  String get orgSwitcherLabel => 'Organization';

  @override
  String get acceptInvitationTitle => 'Accept invitation';

  @override
  String get acceptInvitationBody =>
      'Paste the one-time token your partner shared with you.';

  @override
  String get acceptInvitationAction => 'Accept';

  @override
  String get invitationAccepted => 'Invitation accepted.';

  @override
  String get invitationAcceptedBody => 'You joined the organization.';

  @override
  String get done => 'Done';

  @override
  String get inviteMember => 'Invite Member';

  @override
  String get inviteEmailLabel => 'Invite by email';

  @override
  String get inviteRoleLabel => 'Assign role';

  @override
  String get inviteTokenLabel => 'One-time token';

  @override
  String get inviteSendButton => 'Send Invitation';

  @override
  String inviteTokenBody(String email) {
    return 'Share this one-time token with $email. It cannot be shown again.';
  }

  @override
  String get inviteTokenCopy => 'Copy token';

  @override
  String get inviteTokenCopied => 'Token copied to clipboard.';

  @override
  String get actionResendInvitation => 'Resend invitation';

  @override
  String get actionRevokeInvitation => 'Revoke invitation';

  @override
  String get invitationRevoked => 'Invitation revoked.';

  @override
  String inviteTokenResentBody(String email) {
    return 'A fresh one-time token for $email. It cannot be shown again.';
  }

  @override
  String get memberStatusInvited => 'INVITED';

  @override
  String get memberStatusActive => 'ACTIVE';

  @override
  String get memberStatusSuspended => 'SUSPENDED';

  @override
  String get memberStatusRemoved => 'REMOVED';

  @override
  String get actionSuspend => 'Suspend';

  @override
  String get actionReactivate => 'Reactivate';

  @override
  String get actionRemove => 'Remove';

  @override
  String get removeMemberConfirmTitle => 'Remove member?';

  @override
  String removeMemberConfirmBody(String name) {
    return 'Remove $name from this organization?';
  }

  @override
  String get removeMemberConfirmAction => 'Remove';

  @override
  String get orgErrorDenied =>
      'You don\'t have permission to perform this action.';

  @override
  String get orgErrorDuplicateMember =>
      'This person is already a member of the organization.';

  @override
  String get orgErrorLastPartner =>
      'The organization must keep at least one active partner.';

  @override
  String get orgErrorInvalidRole => 'This role cannot be assigned.';

  @override
  String get orgErrorInvalidName => 'The organization name cannot be empty.';

  @override
  String get orgErrorInvalidInvitation =>
      'The invitation is invalid or expired.';

  @override
  String get orgErrorProviderUnavailable =>
      'The service is unavailable right now. Please try again.';

  @override
  String get orgErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get signUpCheckInboxTitle => 'Check Your Inbox';

  @override
  String get signUpCheckInboxBody =>
      'We\'ve sent a verification link to your email. Open it to activate your account, then sign in.';

  @override
  String get signUpCheckInboxAction => 'Continue to Sign In';

  @override
  String get bookingTitle => 'Book a Consultation';

  @override
  String get bookingLocalOnlyNote =>
      'Demo mode — no consultation is actually booked or sent.';

  @override
  String get bookingCategoryStepTitle => 'Consultation type';

  @override
  String get bookingCategoryGeneral => 'General';

  @override
  String get bookingCategoryFollowUp => 'Follow-up';

  @override
  String get bookingCategoryUrgent => 'Urgent';

  @override
  String get bookingTopicLabel => 'Topic (optional)';

  @override
  String get bookingTopicPlaceholder => 'Briefly describe your question';

  @override
  String get bookingContinue => 'Continue';

  @override
  String get bookingSelectDateTimeStep => 'Select date & time';

  @override
  String get bookingSlotsEmpty => 'No times available.';

  @override
  String get bookingSlotsError => 'Unable to load available times.';

  @override
  String bookingDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get bookingReviewStep => 'Review your booking';

  @override
  String get bookingSummaryType => 'Type';

  @override
  String get bookingSummaryTopic => 'Topic';

  @override
  String get bookingSummaryTime => 'Time';

  @override
  String get bookingSummaryNotSet => 'Not specified';

  @override
  String get bookingEditCategory => 'Edit category';

  @override
  String get bookingConfirm => 'Confirm booking';

  @override
  String get bookingConfirmFailed => 'Unable to confirm. Please try again.';

  @override
  String get bookingSuccessTitle => 'Booking confirmed';

  @override
  String bookingSuccessBody(String referenceId) {
    return 'Reference: $referenceId';
  }

  @override
  String get bookingDone => 'Done';

  @override
  String get bookingEntryTitle => 'Book a consultation';

  @override
  String get bookingEntrySubtitle =>
      'Schedule a consultation — development demo.';

  @override
  String get discoveryTitle => 'Find an Attorney';

  @override
  String get discoverySearchHint => 'Search by name or practice area';

  @override
  String get discoveryFilterAll => 'All';

  @override
  String get discoveryEmpty => 'No attorneys match your search.';

  @override
  String get discoveryError => 'Unable to load attorneys.';

  @override
  String get discoveryLocalOnlyNote =>
      'Demo mode — synthetic profiles only. No real attorneys are listed or contacted.';

  @override
  String get discoveryEntryTitle => 'Find an attorney';

  @override
  String get discoveryEntrySubtitle =>
      'Browse demo attorney profiles — development demo.';

  @override
  String get bookingSummaryAttorney => 'Attorney';

  @override
  String bookingAttorneyPrefill(String name) {
    return 'Booking with $name';
  }

  @override
  String get discoveryProfileTitle => 'Attorney profile';

  @override
  String get discoveryProfileNotFound => 'Attorney not found.';

  @override
  String get discoveryProfileBio => 'About';

  @override
  String get discoveryProfileBook => 'Book with this attorney';

  @override
  String get matterTitle => 'Matters';

  @override
  String get matterFilterAll => 'All';

  @override
  String get matterStatusOpen => 'Open';

  @override
  String get matterStatusActive => 'Active';

  @override
  String get matterStatusClosed => 'Closed';

  @override
  String get matterEmpty => 'No matters match the filter.';

  @override
  String get matterError => 'Unable to load matters.';

  @override
  String get matterLocalOnlyNote =>
      'Demo mode — synthetic matters only. No real cases are listed.';

  @override
  String get matterEntryTitle => 'My matters';

  @override
  String get matterEntrySubtitle =>
      'Browse demo matter files — development demo.';

  @override
  String get matterDetailsTitle => 'Matter details';

  @override
  String get matterDetailsNotFound => 'Matter not found.';

  @override
  String get matterDetailsPracticeArea => 'Practice area';

  @override
  String get matterDetailsAssignedAttorney => 'Assigned attorney';

  @override
  String get matterDetailsCreated => 'Created';

  @override
  String get vaultTitle => 'Documents';

  @override
  String get vaultEmpty => 'No documents are available.';

  @override
  String get vaultError => 'Unable to load documents.';

  @override
  String get vaultLocalOnlyNote =>
      'Demo mode — synthetic document metadata only. No real files are listed.';

  @override
  String get vaultEntryTitle => 'Document vault';

  @override
  String get vaultEntrySubtitle =>
      'Browse demo document metadata — development demo.';

  @override
  String get documentTypeContract => 'Contract';

  @override
  String get documentTypeBrief => 'Brief';

  @override
  String get documentTypeEvidence => 'Evidence';

  @override
  String get documentTypeCorrespondence => 'Correspondence';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesEmpty => 'No message threads are available.';

  @override
  String get messagesError => 'Unable to load message threads.';

  @override
  String get messagesLocalOnlyNote =>
      'Demo mode — synthetic thread metadata only. No real messages are listed.';

  @override
  String get messagesEntryTitle => 'Messages';

  @override
  String get messagesEntrySubtitle =>
      'Browse demo message threads — development demo.';

  @override
  String messagesMessageCount(Object count) {
    return '$count messages';
  }

  @override
  String get matterWorkspaceDocumentsTitle => 'Documents';

  @override
  String get matterWorkspaceDocumentsEmpty =>
      'No documents are available for this matter.';

  @override
  String get matterWorkspaceMessagesTitle => 'Messages';

  @override
  String get matterWorkspaceMessagesEmpty =>
      'No message threads are available for this matter.';
}
