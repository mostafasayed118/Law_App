import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';

/// An [ElevatedButton] that shows a small spinner in place of its label while
/// [loading] is true and is disabled in that state.
class LoadingElevatedButton extends StatelessWidget {
  const LoadingElevatedButton({
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.icon,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget content = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon == null
              ? Text(label, textAlign: TextAlign.center)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Flexible so the label wraps instead of overflowing the
                    // button at large text scales (320px / 2.0 broke the
                    // sign-up and password-reset CTAs by 121px).
                    Flexible(child: Text(label, textAlign: TextAlign.center)),
                    const SizedBox(width: LegalHubTheme.spaceSm),
                    Icon(icon, size: 18),
                  ],
                ));
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: content,
    );
  }
}
