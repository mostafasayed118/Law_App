part of 'sign_up_screen.dart';

/// The post-submit success surface (Phase 4.2).
///
/// Replaces the form once the [SignUpCubit] reports success: a hero badge,
/// the "check your inbox" message, and a single action that routes to
/// sign-in. The user is never silently routed away — verification is enabled
/// server-side, so the confirmation states what happens next instead of
/// implying the account is immediately usable.
class _CheckInboxSuccess extends StatelessWidget {
  const _CheckInboxSuccess({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: LegalHubTheme.spaceXl,
          ),
          child: Center(
            child: IconHeroBadge(
              icon: Icons.mark_email_read_outlined,
              background: scheme.secondaryContainer,
              iconColor: scheme.onSecondary,
            ),
          ),
        ),
        Text(
          l10n.signUpCheckInboxTitle,
          textAlign: TextAlign.center,
          style: text.displayMedium,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        Text(
          l10n.signUpCheckInboxBody,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl * 1.5),
        ElevatedButton(
          onPressed: onContinue,
          child: Text(l10n.signUpCheckInboxAction),
        ),
      ],
    );
  }
}
