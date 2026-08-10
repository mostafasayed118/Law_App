import 'package:flutter/widgets.dart';

import '../../app/legalhub_theme.dart';

/// Material 3 window size classes (the width buckets the design system uses
/// for adaptive layout). The LegalHub surfaces keep a single-column layout on
/// phones, gain breathing room and content centering on tablets, and cap the
/// content column on expanded screens instead of stretching full-bleed.
///
/// The same thresholds as Flutter's `Breakpoints` helper: compact < 600,
/// medium 600–840, expanded ≥ 840.
enum ResponsiveBreakpoint { compact, medium, expanded }

extension ResponsiveBreakpointContext on BuildContext {
  /// The current width bucket from [MediaQuery.sizeOf].
  ResponsiveBreakpoint get breakpoint {
    final double width = MediaQuery.sizeOf(this).width;
    if (width >= 840) {
      return ResponsiveBreakpoint.expanded;
    }
    if (width >= 600) {
      return ResponsiveBreakpoint.medium;
    }
    return ResponsiveBreakpoint.compact;
  }

  /// True on phone-class widths (< 600 logical px).
  bool get isCompact => breakpoint == ResponsiveBreakpoint.compact;

  /// True on tablet widths (600–840 logical px).
  bool get isMedium => breakpoint == ResponsiveBreakpoint.medium;

  /// True on tablet/desktop widths (≥ 840 logical px).
  bool get isExpanded => breakpoint == ResponsiveBreakpoint.expanded;

  /// Adaptive horizontal gutter: the design-system mobile margin on phones,
  /// the desktop margin on expanded screens, and a middle value on tablets.
  /// Screens that already pad with [LegalHubTheme.marginMobile] keep that
  /// padding inside the centered content column; this helper is for surfaces
  /// that want the gutter to grow with the window.
  double get responsiveHorizontalPadding => switch (breakpoint) {
    ResponsiveBreakpoint.compact => LegalHubTheme.marginMobile,
    ResponsiveBreakpoint.medium => 24,
    ResponsiveBreakpoint.expanded => LegalHubTheme.marginDesktop,
  };
}
