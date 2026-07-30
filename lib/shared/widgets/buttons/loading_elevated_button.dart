import 'package:flutter/material.dart';

/// An [ElevatedButton] that shows a small spinner in place of its label while
/// [loading] is true and is disabled in that state.
///
/// Replaces the inline `SizedBox.square(dimension: 18) + CircularProgressIndicator`
/// pattern duplicated across the auth/access screens.
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
              ? Text(label)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label),
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ));

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: content,
    );
  }
}
