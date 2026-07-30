import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/legalhub_theme.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(widget.length, (int i) {
        return SizedBox(
          width: 48,
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
            style: Theme.of(context).textTheme.headlineMedium,
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
        );
      }),
    );
  }
}
