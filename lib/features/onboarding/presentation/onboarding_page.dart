part of 'onboarding_screen.dart';

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight): the
    // page is vertically centered when the viewport is tall enough, and
    // scrolls when it is not. Fixes D-T1 (overflow at compact/desktop
    // heights like the 800x600 widget-test surface) without changing the
    // centered look at phone-class sizes.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 2 * LegalHubTheme.marginMobile,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 240,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: LegalHubTheme.spaceXl,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(LegalHubTheme.radiusXl),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 96,
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.displaySmall,
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
