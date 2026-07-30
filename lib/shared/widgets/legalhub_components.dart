import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A compact app bar used by the auth/onboarding flows.
///
/// Shows the centered LegalHub wordmark, an optional leading back button, and
/// an optional trailing action. Mirrors the `<header>` pattern in the designs.
/// Per decision D-01 the product brand is LegalHub; the wordmark is localized
/// via [AppLocalizations.appTitle].
///
/// This is the only genuinely cross-feature component in this file; the other
/// former occupants (SectionHeader, StatusChip, IdentityCard, PracticeAreaCard)
/// were single-consumer (home dashboard) widgets and have been relocated to
/// `features/home/presentation/widgets/home_cards.dart`. ActionTray had zero
/// consumers and was deleted (see ADR-0004).
class LegalHubAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LegalHubAppBar({
    this.leading,
    this.actions,
    this.centerTitle = true,
    super.key,
  });

  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      title: Text(
        AppLocalizations.of(context).appTitle,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      titleSpacing: 0,
    );
  }
}
