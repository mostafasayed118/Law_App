/// Shared adaptive-window contract.
///
/// Flutter's own window-size classes are implicit (you compare widths by
/// hand); these are the app's single source of truth so the shell, the
/// content wrapper, and modal sheets cannot drift apart.
///
/// Values follow Material 3 window size classes:
/// - compact  : < 600  → bottom navigation, full-bleed sheets
/// - medium   : 600–839 → bottom navigation (rail adoption is backlog)
/// - expanded : >= 840  → leading rail + a readable, centered content column
abstract final class AppBreakpoints {
  AppBreakpoints._();

  /// Medium → expanded boundary; the shell swaps the bottom bar for a rail
  /// and content stops stretching full-bleed.
  static const double expanded = 840;

  /// The widest a modal bottom sheet may grow on a tablet/desktop window.
  static const double sheetMaxWidth = 640;

  /// The widest an auth/onboarding form column may grow.
  static const double authContentMaxWidth = 520;
}
