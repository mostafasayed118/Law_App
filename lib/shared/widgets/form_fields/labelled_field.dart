import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../formatting/display_case.dart';

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
        // Wrap (not a fixed Row) so a wide label + trailing pair — e.g. the
        // sign-in "PASSWORD" + "Forgot Password?" link — stays on one line
        // when it fits and wraps the trailing to a second line instead of
        // overflowing on narrow screens or large text scales.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runAlignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: LegalHubTheme.spaceSm,
          children: <Widget>[
            Text(
              displayUppercase(label, Localizations.localeOf(context)),
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
