import 'package:flutter/material.dart';

import 'labelled_field.dart';

/// A password field with a built-in show/hide toggle.
///
/// Owns the obscure state internally so callers no longer have to thread a
/// `setState` toggle (the pattern was duplicated three times across the auth
/// screens). The field's value is still owned by the supplied [controller].
///
/// When [label] is supplied, the field is wrapped in a [LabelledField] row that
/// also supports an optional [trailing] widget (e.g. a "Forgot password?" link).
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.hint,
    this.label,
    this.trailing,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String hint;

  /// Optional all-caps label rendered above the field.
  final String? label;

  /// Optional widget placed at the end of the label row.
  final Widget? trailing;

  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: Icon(
        _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _obscured = !_obscured),
    );

    final field = TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20)
            : null,
        suffixIcon: toggle,
      ),
    );

    if (widget.label == null && widget.trailing == null) {
      return field;
    }

    return LabelledField(
      label: widget.label ?? '',
      trailing: widget.trailing,
      child: field,
    );
  }
}
