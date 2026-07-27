import 'package:flutter/material.dart';

/// The single light theme for the bootstrap application.
///
/// Tokens follow the canonical LegalHub design system. Dark theme values are
/// intentionally not defined until the approved D-14 palette exists.
class LegalHubTheme {
  LegalHubTheme._();

  static const Color primary = Color(0xFF0B1D2E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B1D2E);
  static const Color onPrimaryContainer = Color(0xFF74859B);
  static const Color secondary = Color(0xFF775A19);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFDD587);
  static const Color onSecondaryContainer = Color(0xFF785A19);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE6EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD5E3FC);
  static const Color onSurface = Color(0xFF0D1C2E);
  static const Color onSurfaceVariant = Color(0xFF44474C);
  static const Color outline = Color(0xFF74777D);
  static const Color outlineVariant = Color(0xFFC4C6CD);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double marginMobile = 20;
  static const double marginDesktop = 40;
  static const double radiusSm = 2;
  static const double radiusDefault = 4;
  static const double radiusMd = 6;
  static const double radiusLg = 8;
  static const double radiusXl = 12;

  static ThemeData get light => forLocale(const Locale('en'));

  static ThemeData forLocale(Locale locale) {
    const ColorScheme scheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      outline: outline,
      outlineVariant: outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: locale.languageCode == 'ar' ? 'NotoNaskhArabic' : 'NotoSans',
      textTheme: _textTheme(locale),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLowest,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          spaceMd,
          14,
          spaceMd,
          14,
        ),
        border: _inputBorder,
        enabledBorder: _inputBorder,
        focusedBorder: _inputBorder.copyWith(
          borderSide: const BorderSide(color: secondary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          side: const BorderSide(color: outlineVariant),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: outlineVariant, thickness: 1),
    );
  }

  static const OutlineInputBorder _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
    borderSide: BorderSide(color: outlineVariant),
  );

  static TextTheme _textTheme(Locale locale) {
    final bool isArabic = locale.languageCode == 'ar';
    final String bodyFamily = isArabic ? 'NotoNaskhArabic' : 'NotoSans';
    final String headingFamily = isArabic
        ? 'NotoNaskhArabic'
        : 'PlayfairDisplay';
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFamily,
        fontSize: 48,
        height: 56 / 48,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFamily,
        fontSize: 30,
        height: 38 / 30,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFamily,
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: primary,
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
    );
  }
}
