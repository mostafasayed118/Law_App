import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// Onboarding success confirmation matching
/// `stitch_legalhub_mobile_app/onboarding_success`.
///
/// Routes to sign-in. Presentation only; no state is persisted.
class OnboardingSuccessScreen extends StatelessWidget {
  const OnboardingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(
              LegalHubTheme.marginMobile,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: LegalHubTheme.spaceXl,
                  ),
                  child: Center(
                    child: IconHeroBadge(
                      icon: Icons.check,
                      background: scheme.secondaryContainer,
                      iconColor: scheme.onSecondary,
                    ),
                  ),
                ),
                Text(
                  l10n.onboardingSuccessTitle,
                  textAlign: TextAlign.center,
                  style: text.displayMedium,
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
                Text(
                  l10n.onboardingSuccessBody,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.signIn),
                  child: Text(l10n.onboardingSuccessAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
