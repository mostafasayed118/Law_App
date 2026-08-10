import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/legalhub_theme.dart';

/// A row of [length] single-digit cells for entering a verification code.
///
/// Owns its own controllers and focus nodes and advances focus automatically as
/// the user types. When [completionNotifier] is supplied, it is updated with
/// `true` once every cell is filled and `false` otherwise, so a submit button
/// can bind to it without re-reading the controllers.
///
/// Call [code] via a [GlobalKey<OtpFieldRowState>] to read the concatenated
/// digits; call [OtpFieldRowState.clear] to reset.
class OtpFieldRow extends StatefulWidget {
  const OtpFieldRow({this.length = 6, this.completionNotifier, super.key})
    : assert(length > 0);

  final int length;

  /// Optional notifier updated with the all-cells-filled state.
  final ValueNotifier<bool>? completionNotifier;

  @override
  State<OtpFieldRow> createState() => OtpFieldRowState();
}

class OtpFieldRowState extends State<OtpFieldRow> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _nodes = List<FocusNode>.generate(widget.length, (_) => FocusNode());
    _publish();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    for (final FocusNode n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Concatenated digit string entered so far.
  String get code =>
      _controllers.map((TextEditingController c) => c.text).join();

  /// Clears all cells.
  void clear() {
    for (final TextEditingController c in _controllers) {
      c.clear();
    }
    _publish();
  }

  bool get _isComplete =>
      _controllers.every((TextEditingController c) => c.text.isNotEmpty);

  void _publish() {
    widget.completionNotifier?.value = _isComplete;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Responsive cells: six fixed 48px cells overflow the ~280px available on
    // a 320px phone (6×48 = 288), so the cells share the available width via
    // Expanded instead of a hardcoded 48. The row is capped at 360 so cells
    // never stretch absurdly wide on tablets. The digit is capped at 32px so
    // a single cell keeps the glyph inside the cell at 2.0 text scale.
    final double digitSize = MediaQuery.textScalerOf(
      context,
    ).scale(22.0).clamp(22.0, 32.0);
    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < widget.length; i++) {
      if (i > 0) {
        cells.add(const SizedBox(width: LegalHubTheme.spaceSm));
      }
      cells.add(
        Expanded(
          child: SizedBox(
            height: 56,
            child: TextField(
              controller: _controllers[i],
              focusNode: _nodes[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: digitSize,
                height: 1,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(LegalHubTheme.radiusDefault),
                  ),
                  borderSide: BorderSide(color: scheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(LegalHubTheme.radiusDefault),
                  ),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
              onChanged: (String value) {
                if (value.isNotEmpty && i < widget.length - 1) {
                  _nodes[i + 1].requestFocus();
                }
                _publish();
              },
            ),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(children: cells),
      ),
    );
  }
}
