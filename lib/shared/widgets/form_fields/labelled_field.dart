import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';

/// A labelled form-field row used across the auth/onboarding flows.
///
/// Renders an all-caps label above [child], with an optional [trailing] widget
/// aligned to the end of the label row (e.g. a "Forgot password?" link).
///
/// This widget is purely presentational; the field itself is supplied by the
/// caller so it can be wired to its own controller/validator.
class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.child,
    this.trailing,
    super.key,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: LegalHubTheme.spaceXs),
        child,
      ],
    );
  }
}
