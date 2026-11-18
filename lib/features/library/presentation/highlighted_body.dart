import 'package:flutter/gestures.dart';
import 'package:legalhub/features/library/domain/highlight_offsets.dart';
import 'package:legalhub/features/library/domain/legal_highlight.dart';
import 'package:legalhub/features/library/presentation/highlight_palette.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The article body, selectable, with highlights painted behind their spans.
///
/// Three things have to agree here, and they are the whole reason this is a
/// stateful widget:
///
/// 1. **Offsets.** Highlights are stored in rune offsets; Flutter renders in
///    UTF-16. Every span boundary is converted through [utf16OffsetOf], so an
///    article containing an astral character does not shift every highlight
///    after it.
/// 2. **Selection.** [SelectableText.rich] reports UTF-16 offsets into the
///    concatenated span text. Because the spans never insert characters, those
///    offsets are the body's own offsets, which is why the caller can hand them
///    straight to the cubit (which converts to runes).
/// 3. **Recognizers.** A tap target per highlight needs a
///    [TapGestureRecognizer] that is disposed. They are rebuilt only when the
///    highlight set changes.
///
/// Stale highlights are never passed in: drawing them at their old offsets would
/// underline whatever words now live there. The reader shows those separately.
class HighlightedBody extends StatefulWidget {
  const HighlightedBody({
    required this.body,
    required this.highlights,
    required this.textStyle,
    required this.onSelectionHighlight,
    required this.onHighlightTapped,
    super.key,
  });

  final String body;

  /// Non-stale highlights only, in any order.
  final List<LegalHighlight> highlights;

  final TextStyle? textStyle;

  /// Called with UTF-16 start/end offsets of the user's selection.
  final void Function(int startUtf16, int endUtf16) onSelectionHighlight;

  /// Called when an existing highlight is tapped.
  final void Function(LegalHighlight highlight) onHighlightTapped;

  @override
  State<HighlightedBody> createState() => _HighlightedBodyState();
}

class _HighlightedBodyState extends State<HighlightedBody> {
  final Map<String, TapGestureRecognizer> _recognizers =
      <String, TapGestureRecognizer>{};

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(LegalHighlight highlight) {
    return _recognizers.putIfAbsent(
      highlight.id,
      () =>
          TapGestureRecognizer()
            ..onTap = () => widget.onHighlightTapped(highlight),
    );
  }

  /// Drops recognizers whose highlight no longer exists, so a deleted highlight
  /// does not keep its handler alive.
  void _pruneRecognizers() {
    final Set<String> live = widget.highlights
        .map((LegalHighlight h) => h.id)
        .toSet();
    final List<String> gone = _recognizers.keys
        .where((String id) => !live.contains(id))
        .toList(growable: false);
    for (final String id in gone) {
      _recognizers.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    _pruneRecognizers();

    final List<LegalHighlight> ordered = <LegalHighlight>[...widget.highlights]
      ..sort(
        (LegalHighlight a, LegalHighlight b) =>
            a.startOffset.compareTo(b.startOffset),
      );
    final int bodyRunes = widget.body.runes.length;
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    for (final LegalHighlight highlight in ordered) {
      final int start = highlight.startOffset.clamp(0, bodyRunes);
      final int end = highlight.endOffset.clamp(start, bodyRunes);
      // Defensive: an overlapping highlight is skipped rather than drawn on top
      // of the previous one, which would stack two backgrounds and mislead.
      if (start < cursor || end <= start) {
        continue;
      }
      if (start > cursor) {
        spans.add(TextSpan(text: substringByRunes(widget.body, cursor, start)));
      }
      spans.add(
        TextSpan(
          text: substringByRunes(widget.body, start, end),
          style: TextStyle(
            backgroundColor: HighlightPalette.background(
              context,
              highlight.color,
            ),
          ),
          recognizer: _recognizerFor(highlight),
        ),
      );
      cursor = end;
    }
    if (cursor < bodyRunes) {
      spans.add(
        TextSpan(text: substringByRunes(widget.body, cursor, bodyRunes)),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: widget.textStyle,
      contextMenuBuilder:
          (BuildContext context, EditableTextState editableTextState) {
            final TextSelection selection =
                editableTextState.textEditingValue.selection;
            final List<ContextMenuButtonItem> items = <ContextMenuButtonItem>[
              if (selection.isValid && !selection.isCollapsed)
                ContextMenuButtonItem(
                  label: l10n.libraryHighlightAction,
                  onPressed: () {
                    editableTextState.hideToolbar();
                    widget.onSelectionHighlight(selection.start, selection.end);
                  },
                ),
              ...editableTextState.contextMenuButtonItems,
            ];
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: items,
            );
          },
    );
  }
}
