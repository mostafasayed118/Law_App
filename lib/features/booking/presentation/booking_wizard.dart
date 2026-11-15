part of 'booking_screen.dart';

class _BookingWizard extends StatelessWidget {
  const _BookingWizard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookingTitle),
        leading: BackButton(
          onPressed: () {
            final BookingState state = context.read<BookingCubit>().state;
            // The wizard shell's back button steps back one step; on the
            // first (category) step and the terminal (success) step it exits
            // to home (scope note D-B4, cubit `back()` semantics).
            if (state.step == BookingStep.category ||
                state.step == BookingStep.success) {
              context.go(AppRoutes.home);
            } else {
              context.read<BookingCubit>().back();
            }
          },
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (BuildContext context, BookingState state) {
            final Widget step = switch (state.step) {
              BookingStep.category => _CategoryStep(state: state),
              BookingStep.dateTime => _DateTimeStep(state: state),
              BookingStep.review => _ReviewStep(state: state),
              BookingStep.success => _SuccessStep(state: state),
            };
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Landscape/tablet: the step column plus a persistent draft
                // summary. The review and success steps already are a
                // summary/confirmation, so they keep the full width.
                final bool showSummary =
                    constraints.maxWidth >= AppBreakpoints.expanded &&
                    state.step != BookingStep.review &&
                    state.step != BookingStep.success;
                if (!showSummary) {
                  return step;
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: step),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 320,
                      child: _DraftSummaryPanel(state: state),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
