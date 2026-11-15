import 'package:flutter/material.dart';

import 'package:legalhub/shared/responsive/breakpoints.dart';

/// The widest a modal sheet may be on tablet/desktop windows.
///
/// Material's modal bottom sheet is full-bleed by default: on a 1024px window
/// a create/edit form stretched across the whole width, which is both hard to
/// scan and visually detached from the phone layout. Capping the sheet keeps
/// the form a readable column and leaves the scrim visible on both sides.
/// Phones are unaffected (`min(viewport, 640)` is the viewport).
const double appSheetMaxWidth = AppBreakpoints.sheetMaxWidth;

/// The widest a wide-window dialog may grow (Material's dialog body width).
const double appDialogMaxWidth = 560;

/// Opens the app's standard modal surface.
///
/// Compact/medium windows get the bottom sheet: scroll-controlled,
/// keyboard-aware, and width-capped. Expanded windows (≥840) get a centered
/// dialog instead — a bottom-anchored sheet on a desktop window reads as a
/// phone artifact, and a dialog keeps the form near the user's focus.
///
/// All create/detail/payment surfaces share this one contract. Pass
/// `dialogOnWide: false` only when the surface genuinely needs the sheet
/// gesture (e.g. a future drag-to-expand media sheet).
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dialogOnWide = true,
}) {
  final bool wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
  if (wide && dialogOnWide) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: appDialogMaxWidth,
            maxHeight: appDialogMaxWidth * 1.6,
          ),
          child: builder(dialogContext),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: appSheetMaxWidth),
    builder: builder,
  );
}
