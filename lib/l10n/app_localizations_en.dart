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
}
