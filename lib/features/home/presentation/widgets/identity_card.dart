import 'package:flutter/material.dart';

import '../../../../app/legalhub_theme.dart';

/// An identity card with a 4px left accent bar (Secondary Gold by default).
class IdentityCard extends StatelessWidget {
  const IdentityCard({
    required this.child,
    this.accentColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: const BorderRadius.all(
        Radius.circular(LegalHubTheme.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: accentColor ?? scheme.secondary,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                LegalHubTheme.spaceMd,
                LegalHubTheme.spaceMd,
                LegalHubTheme.spaceMd,
                LegalHubTheme.spaceMd,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
