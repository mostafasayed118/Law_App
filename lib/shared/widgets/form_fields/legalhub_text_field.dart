import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/legalhub_theme.dart';

/// A single-line text field with optional label, prefix icon, hint, suffix,
/// keyboard type, input formatters, and validator.
///
/// Consolidates the field shapes used across the auth/onboarding screens. The
/// label is rendered above the field in `bodySmall` (matching the sign-up icon
/// fields); callers that need the all-caps label variant can wrap the field in
/// [LabelledField] instead of passing [label] here.
class LegalHubTextField extends StatelessWidget {
  const LegalHubTextField({
    required this.controller,
    required this.hint,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.textAlign,
    this.style,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;

  /// Optional label rendered above the field in `bodySmall`.
  final String? label;

  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextAlign? textAlign;
  final TextStyle? style;

  /// Optional live-edit callback (e.g. client-side filtering).
  final ValueChanged<String>? onChanged;

  /// Optional submit callback (e.g. navigation on the keyboard action).
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      textAlign: textAlign ?? TextAlign.start,
      style: style,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon,
      ),
    );

    if (label == null) {
      return field;
    }

    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label!, style: text.bodySmall?.copyWith(color: scheme.onSurface)),
        const SizedBox(height: LegalHubTheme.spaceXs),
        field,
      ],
    );
  }
}
