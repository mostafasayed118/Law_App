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
            return switch (state.step) {
              BookingStep.category => _CategoryStep(state: state),
              BookingStep.dateTime => _DateTimeStep(state: state),
              BookingStep.review => _ReviewStep(state: state),
              BookingStep.success => _SuccessStep(state: state),
            };
          },
        ),
      ),
    );
  }
}
