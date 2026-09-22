part of 'legalhub_theme.dart';

/// Semantic status colors for the current brightness.
///
/// M3's [ColorScheme] carries `error` natively; the design system's
/// success / warning / info tokens are exposed here so screens read them
/// from the theme (never hardcode a status color). Status is still never
/// communicated by color alone (INSTRUCTIONS §4.5) — these back icons and
/// labels that already carry text.
extension LegalHubColorScheme on ColorScheme {
  Color get success => brightness == Brightness.dark
      ? LegalHubTheme.darkSuccess
      : LegalHubTheme.success;

  Color get onSuccess => brightness == Brightness.dark
      ? LegalHubTheme.darkOnSuccess
      : LegalHubTheme.onSuccess;

  Color get warning => brightness == Brightness.dark
      ? LegalHubTheme.darkWarning
      : LegalHubTheme.warning;

  Color get onWarning => brightness == Brightness.dark
      ? LegalHubTheme.darkOnWarning
      : LegalHubTheme.onWarning;

  Color get info => brightness == Brightness.dark
      ? LegalHubTheme.darkInfo
      : LegalHubTheme.info;

  Color get onInfo => brightness == Brightness.dark
      ? LegalHubTheme.darkOnInfo
      : LegalHubTheme.onInfo;
}
