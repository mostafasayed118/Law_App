import 'package:flutter/material.dart';

/// The canonical LegalHub design-system tokens, light and dark.
///
/// Tokens follow the "Lex Juris" system: Midnight Blue primary, Old Gold
/// secondary, tiered cool-white surfaces, Playfair Display + Inter pairing.
/// Light values match the light-mode designs; dark values match the
/// `*_dark_mode` designs (e.g. `home_dashboard_dark_mode`).
class LegalHubTheme {
  LegalHubTheme._();

  // --- Light tokens ---------------------------------------------------------
  static const Color primary = Color(0xFF041627);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1A2B3C);
  static const Color onPrimaryContainer = Color(0xFF8192A7);
  static const Color secondary = Color(0xFF775A19);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFED488);
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

  // --- Dark tokens ---------------------------------------------------------
  static const Color darkPrimary = Color(0xFFB7C8DE);
  static const Color darkOnPrimary = Color(0xFF041627);
  static const Color darkPrimaryContainer = Color(0xFFD2E4FB);
  static const Color darkOnPrimaryContainer = Color(0xFF0B1D2D);
  static const Color darkSecondary = Color(0xFFE9C176);
  static const Color darkOnSecondary = Color(0xFF422C00);
  static const Color darkSecondaryContainer = Color(0xFF5D4201);
  static const Color darkOnSecondaryContainer = Color(0xFFFFDEA5);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkSurface = Color(0xFF0D1C2E);
  static const Color darkSurfaceLowest = Color(0xFF0B1D2D);
  static const Color darkSurfaceContainerLow = Color(0xFF1A2B3C);
  static const Color darkSurfaceContainer = Color(0xFF1A2B3C);
  static const Color darkSurfaceContainerHigh = Color(0xFF233144);
  static const Color darkSurfaceContainerHighest = Color(0xFF334455);
  static const Color darkOnSurface = Color(0xFFEAF1FF);
  static const Color darkOnSurfaceVariant = Color(0xFFC4C6CD);
  static const Color darkOutline = Color(0xFF8E9199);
  static const Color darkOutlineVariant = Color(0xFF44474C);

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
  static const double radiusFull = 9999;

  static ThemeData get light => forBrightness(Brightness.light);
  static ThemeData get dark => forBrightness(Brightness.dark);

  /// Light theme for a given locale (back-compat with existing call sites).
  static ThemeData forLocale(Locale locale) =>
      _build(brightness: Brightness.light, locale: locale);

  /// Theme for a brightness/locale pair. Locale selects font families so
  /// Arabic uses Noto Naskh and Latin uses Playfair/Inter.
  static ThemeData forBrightness(
    Brightness brightness, {
    Locale locale = const Locale('en'),
  }) => _build(brightness: brightness, locale: locale);

  static ThemeData _build({
    required Brightness brightness,
    required Locale locale,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = isDark
        ? const ColorScheme.dark(
            primary: darkPrimary,
            onPrimary: darkOnPrimary,
            primaryContainer: darkPrimaryContainer,
            onPrimaryContainer: darkOnPrimaryContainer,
            secondary: darkSecondary,
            onSecondary: darkOnSecondary,
            secondaryContainer: darkSecondaryContainer,
            onSecondaryContainer: darkOnSecondaryContainer,
            surface: darkSurface,
            onSurface: darkOnSurface,
            surfaceContainerLowest: darkSurfaceLowest,
            surfaceContainerLow: darkSurfaceContainerLow,
            surfaceContainer: darkSurfaceContainer,
            surfaceContainerHigh: darkSurfaceContainerHigh,
            surfaceContainerHighest: darkSurfaceContainerHighest,
            error: darkError,
            onError: darkOnError,
            errorContainer: darkErrorContainer,
            onErrorContainer: darkOnErrorContainer,
            outline: darkOutline,
            outlineVariant: darkOutlineVariant,
          )
        : const ColorScheme.light(
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

    final Color scaffoldBg = isDark ? darkSurface : surface;
    final Color appBarBg = isDark ? darkSurface : surface;
    final Color appBarFg = isDark ? darkPrimary : primary;
    final Color inputFill = isDark ? darkSurfaceLowest : surfaceLowest;
    final Color inputBorder = isDark ? darkOutlineVariant : outlineVariant;
    final Color focusBorder = isDark ? darkSecondary : secondary;
    final Color buttonBorder = isDark ? darkOutlineVariant : outlineVariant;
    final Color dividerColor = isDark ? darkOutlineVariant : outlineVariant;
    final Color onSurfaceColor = isDark ? darkOnSurface : onSurface;
    final Color onSurfaceVariantColor = isDark
        ? darkOnSurfaceVariant
        : onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: locale.languageCode == 'ar' ? 'NotoNaskhArabic' : 'NotoSans',
      textTheme: _textTheme(
        locale,
        isDark: isDark,
        onSurface: onSurfaceColor,
        onSurfaceVariant: onSurfaceVariantColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          spaceMd,
          14,
          spaceMd,
          14,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
          borderSide: BorderSide(color: focusBorder, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? darkPrimary : primary,
          foregroundColor: isDark ? darkOnPrimary : onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurfaceColor,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          side: BorderSide(color: buttonBorder),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurfaceLowest : surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
    );
  }

  static TextTheme _textTheme(
    Locale locale, {
    required bool isDark,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final bool isArabic = locale.languageCode == 'ar';
    final String bodyFamily = isArabic ? 'NotoNaskhArabic' : 'NotoSans';
    final String headingFamily = isArabic
        ? 'NotoNaskhArabic'
        : 'PlayfairDisplay';
    final Color headingColor = isDark ? darkPrimary : primary;
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
}
