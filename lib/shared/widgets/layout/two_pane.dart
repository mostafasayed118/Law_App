import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

/// Side-by-side master/detail layout for expanded windows (≥840dp).
///
/// The list keeps a narrower share (2/5 by default) and the detail takes the
/// rest. Both panes are full-height, so each owns its own scroll view.
///
/// On a foldable with a vertical hinge, the hinge width replaces the 1px
/// divider: content never renders across the physical gap. [hingeGap] is
/// public so tests (and future layouts) can assert the gap geometry.
class TwoPane extends StatelessWidget {
  const TwoPane({
    required this.list,
    required this.detail,
    this.listFlex = 2,
    this.detailFlex = 3,
    super.key,
  });

  final Widget list;
  final Widget detail;
  final int listFlex;
  final int detailFlex;

  /// Width of a vertical hinge that sits inside the window, or 0.
  ///
  /// Only a `hinge` whose bounds are strictly inside the viewport and whose
  /// height spans the window counts; a fold (crease) keeps the divider, and
  /// cutouts are ignored (they are not a pane separator).
  static double hingeGap(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    for (final DisplayFeature feature in MediaQuery.displayFeaturesOf(
      context,
    )) {
      if (feature.type != DisplayFeatureType.hinge) {
        continue;
      }
      final Rect bounds = feature.bounds;
      if (bounds.width <= 0 || bounds.height <= 0) {
        continue;
      }
      if (bounds.left <= 0 || bounds.right >= size.width) {
        continue;
      }
      if (bounds.height < size.height * 0.8) {
        continue;
      }
      return bounds.width;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final double gap = hingeGap(context);
    return Row(
      children: <Widget>[
        Expanded(flex: listFlex, child: list),
        if (gap > 0)
          SizedBox(key: const Key('two-pane-hinge-gap'), width: gap)
        else
          const VerticalDivider(width: 1),
        Expanded(flex: detailFlex, child: detail),
      ],
    );
  }
}
