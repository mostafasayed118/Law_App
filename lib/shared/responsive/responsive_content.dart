import 'package:flutter/material.dart';

/// Centers and caps the width of a screen's body content.
///
/// On compact (phone) widths the constraint is a no-op: the child keeps the
/// full viewport width, so existing phone layouts are byte-for-byte
/// unchanged. On medium/expanded widths the child is capped at [maxWidth] and
/// horizontally centered, so list/detail surfaces stop stretching
/// full-bleed on tablets and desktop windows.
///
/// Use it as the immediate child of a `Scaffold.body` (or around a scroll
/// view): `body: ResponsiveContent(child: SafeArea(child: ListView(...)))`.
/// The vertical extent is preserved — a [ListView]/[CustomScrollView] child
/// still fills the available height and scrolls normally.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth = 840,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;

  /// The widest the content column may be. Defaults to 840 (the top of the
  /// Material 3 "expanded" size class), which keeps lines readable on large
  /// screens.
  final double maxWidth;

  /// Optional extra gutter applied inside the constrained column. Zero by
  /// default — most screens already pad with the design-system margins.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cap = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cap),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
