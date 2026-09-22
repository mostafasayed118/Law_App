import 'package:flutter/material.dart';

import '../../../../app/legalhub_theme.dart';
import '../../../../shared/formatting/display_case.dart';

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
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
