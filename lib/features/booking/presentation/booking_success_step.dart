part of 'booking_screen.dart';

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: scheme.secondary,
            fill: 1,
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          Text(
            l10n.bookingSuccessTitle,
            textAlign: TextAlign.center,
            style: text.headlineMedium,
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            l10n.bookingSuccessBody(state.confirmation?.referenceId ?? '—'),
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.bookingLocalOnlyNote,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceXl),
          // Spec D-15 demo-posture (A-2: "book" → "join call"): the natural
          // host for the video surface is the booking flow's success step. A
          // navigation hint only — the demo call requests no media and
          // records nothing.
          // E2E BUG-1 fix: forward navigation from the success step must
          // push, so BACK returns to the booking surface rather than
          // exiting the app.
          FilledButton.tonalIcon(
            icon: const Icon(Icons.video_call_outlined),
            label: Text(l10n.videoJoin),
            onPressed: () => context.push(AppRoutes.video),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          // "Done" deliberately RESETS to the root Home tab (the booking
          // flow is complete; there is nothing to return to), so `go` is
          // correct here and must stay.
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(l10n.bookingDone),
          ),
        ],
      ),
    );
  }
}
