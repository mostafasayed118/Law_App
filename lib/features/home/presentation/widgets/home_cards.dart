import 'package:flutter/material.dart';

import '../../../../app/legalhub_theme.dart';

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
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// Small all-caps status chip ("ACTIVE CASE", "ACTION REQUIRED", …).
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.background,
    this.foreground,
    super.key,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LegalHubTheme.spaceSm,
        vertical: LegalHubTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusSm),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground ?? scheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

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

/// A practice-area card with an icon chip and a title, used in the home
/// dashboard's horizontal scroll.
class PracticeAreaCard extends StatelessWidget {
  const PracticeAreaCard({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 160,
          height: 192,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: LegalHubTheme.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 22, color: scheme.onPrimary, fill: 1),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
