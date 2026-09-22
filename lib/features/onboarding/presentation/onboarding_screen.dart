import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

part 'onboarding_page.dart';

/// Three-step onboarding carousel matching
/// `stitch_legalhub_mobile_app/onboarding`.
///
/// On completion it routes to the onboarding-success screen. This is
/// presentation only; no state is persisted. Images in the designs are
/// remote placeholders, so a tonal surface is used instead.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const int _pageCount = 3;

  String _title(int i, AppLocalizations l10n) => <String>[
    l10n.onboardingTitle1,
    l10n.onboardingTitle2,
    l10n.onboardingTitle3,
  ][i];

  String _desc(int i, AppLocalizations l10n) => <String>[
    l10n.onboardingDesc1,
    l10n.onboardingDesc2,
    l10n.onboardingDesc3,
  ][i];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.signIn),
                  child: Text(
                    l10n.skip,
                    style: text.labelLarge?.copyWith(
                      color: scheme.outline,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int i) => setState(() => _current = i),
                children: List<Widget>.generate(_pageCount, (int i) {
                  return _OnboardingPage(
                    color: scheme.surfaceContainerLow,
                    icon: <IconData>[
                      Icons.gavel_outlined,
                      Icons.event_note_outlined,
                      Icons.shield_outlined,
                    ][i],
                    title: _title(i, l10n),
                    description: _desc(i, l10n),
                  );
                }),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(LegalHubTheme.spaceLg),
                ),
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding: const EdgeInsetsDirectional.fromSTEB(
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceLg,
                LegalHubTheme.marginMobile,
                LegalHubTheme.spaceXl,
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(_pageCount, (int i) {
                      final bool active = i == _current;
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsetsDirectional.symmetric(
                            horizontal: LegalHubTheme.spaceXs,
                          ),
                          width: active ? 10 : 8,
                          height: active ? 10 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? scheme.primaryContainer
                                : scheme.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: LegalHubTheme.spaceXl),
                  ElevatedButton.icon(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                    ),
                    icon: DirectionalIcon(
                      icon: Icons.arrow_forward,
                      mirroredIcon: Icons.arrow_back,
                      size: 18,
                    ),
                    label: Text(
                      _current == _pageCount - 1
                          ? l10n.onboardingGetStarted
                          : l10n.onboardingContinue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (_current < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      context.go(AppRoutes.onboardingSuccess);
    }
  }
}
