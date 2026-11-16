part of 'home_screen.dart';

/// The Home bell with its unread badge (ADR-0011).
///
/// Renders a plain bell when no [NotificationBadgeCubit] is provided (widget
/// tests that pump Home in isolation), so adding the badge never breaks an
/// unrelated surface. The badge caps at 99+, keeps its label out of the icon
/// (tooltip + Semantics), and derives its text from an ICU plural so Arabic,
/// English and Turkish all read naturally.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final IconButton bell = IconButton(
      icon: const Icon(Icons.notifications_outlined),
      // The bell opens the org-scoped notification feed — the same surface
      // the home entry card reaches (D-N1). A navigation hint only, never
      // an authorization grant.
      tooltip: l10n.notificationsFeedTitle,
      onPressed: () => context.push(AppRoutes.notificationsFeed),
    );
    // A standalone Home (tests, previews) has no badge provider: keep the
    // plain bell rather than throwing for a decorative hint.
    if (context
            .findAncestorWidgetOfExactType<
              BlocProvider<NotificationBadgeCubit>
            >() ==
        null) {
      return bell;
    }
    return BlocBuilder<NotificationBadgeCubit, int>(
      builder: (BuildContext context, int unread) {
        if (unread <= 0) {
          return Semantics(label: l10n.notificationsFeedTitle, child: bell);
        }
        final String label = l10n.notificationsUnreadBadge(unread);
        return Semantics(
          label: label,
          button: true,
          child: Badge(
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: bell,
          ),
        );
      },
    );
  }
}
