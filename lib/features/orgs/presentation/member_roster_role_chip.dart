part of 'member_roster_screen.dart';

/// Small colored chip rendering a member's organization role.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LabelChip(
      label: roleLabel(AppLocalizations.of(context), role),
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(letterSpacing: 0.3),
      maxLines: null,
    );
  }
}
