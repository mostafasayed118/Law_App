part of 'legalhub_theme.dart';

TextTheme _legalHubTextTheme(
  Locale locale, {
  required bool isDark,
  required Color onSurface,
  required Color onSurfaceVariant,
}) {
  final bool isArabic = locale.languageCode == 'ar';
  final String bodyFamily = isArabic ? 'NotoNaskhArabic' : 'NotoSans';
  final String headingFamily = isArabic ? 'NotoNaskhArabic' : 'PlayfairDisplay';
  final Color headingColor = isDark
      ? LegalHubTheme.darkPrimary
      : LegalHubTheme.primary;
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: headingFamily,
      fontSize: 48,
      height: 56 / 48,
      fontWeight: FontWeight.w700,
      color: headingColor,
    ),
    displayMedium: TextStyle(
      fontFamily: headingFamily,
      fontSize: 30,
      height: 38 / 30,
      fontWeight: FontWeight.w700,
      color: headingColor,
    ),
    displaySmall: TextStyle(
      fontFamily: headingFamily,
      fontSize: 26,
      height: 32 / 26,
      fontWeight: FontWeight.w700,
      color: headingColor,
    ),
    headlineMedium: TextStyle(
      fontFamily: headingFamily,
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      color: headingColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 18,
      height: 28 / 18,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 16,
      height: 24 / 16,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 14,
      height: 20 / 14,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: onSurfaceVariant,
    ),
    labelMedium: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: onSurface,
    ),
  );
}
