part of 'member_roster_screen.dart';

/// Small chip rendering a member's lifecycle status with distinct colors:
/// active/invited in container tones, suspended/removed in error tones.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (String label, Color background, Color foreground) = switch (status) {
      MembershipStatus.active => (
        l10n.memberStatusActive,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      MembershipStatus.invited => (
        l10n.memberStatusInvited,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      MembershipStatus.suspended => (
        l10n.memberStatusSuspended,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      MembershipStatus.removed => (
        l10n.memberStatusRemoved,
        scheme.surfaceContainerHighest,
        scheme.outline,
      ),
    };
    return LabelChip(
      label: label,
      background: background,
      foreground: foreground,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(letterSpacing: 0.3),
      maxLines: null,
    );
  }
}
