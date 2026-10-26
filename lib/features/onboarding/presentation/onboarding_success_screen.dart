import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/data/local/onboarding_store.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// Onboarding success confirmation matching
/// `stitch_legalhub_mobile_app/onboarding_success`.
///
/// Marks onboarding completed, then routes to sign-in.
class OnboardingSuccessScreen extends StatelessWidget {
  const OnboardingSuccessScreen({super.key});

  Future<void> _complete(BuildContext context) async {
    if (serviceLocator.isRegistered<OnboardingStore>()) {
      await serviceLocator<OnboardingStore>().markCompleted();
    }
    if (context.mounted) {
      context.go(AppRoutes.signIn);
    }
  }

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
                  onPressed: () => _complete(context),
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
