import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/shared/formatting/display_case.dart';

/// A section header with an optional trailing "VIEW ALL"-style action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Expanded + ellipsis keeps the trailing action on-screen when the
        // title wraps at narrow widths or large text scales.
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          const SizedBox(width: LegalHubTheme.spaceSm),
          TextButton(
            onPressed: onAction,
            // Compact label, but a real 48px-tall hit target: the previous
            // Size.zero + shrinkWrap shrank the view-all action to the label
            // height (~19px).
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              displayUppercase(actionLabel!, Localizations.localeOf(context)),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
