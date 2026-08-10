import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/booking_category.dart';
import '../domain/booking_gateway.dart';
import '../domain/booking_prefill.dart';
import '../domain/booking_slot.dart';
import 'booking_cubit.dart';
import 'booking_state.dart';

part 'booking_category_step.dart';
part 'booking_datetime_step.dart';
part 'booking_review_step.dart';
part 'booking_selectable_tile.dart';
part 'booking_success_step.dart';

/// Consultation-booking wizard (Phase 5 slice 5.1).
///
/// A single `/book` route with an internal step switcher (scope note D-B4):
/// the draft lives in [BookingCubit] state and is never threaded through
/// route parameters or GoRouter `extra`. The cubit is feature-scoped and
/// created here via [BlocProvider]; it resolves the [BookingGateway] from the
/// service locator (the dev fake in env-less runs). All copy is local-only —
/// no live-payment wording and no backend promise (D-B3/D-B6).
///
/// The step pipeline lives in the `part` files below (Phase-4 readability
/// split): category + topic/prefill, date-time + slot picker, review summary,
/// success, and the shared [BookingState]-aware selectable tile. All are
/// feature-local private widgets; nothing is exported beyond this screen.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingCubit>(
      create: (BuildContext context) {
        // Phase 6 D-A3: a discovery profile may pre-fill the booking with an
        // optional attorney before navigating here. The prefill is consumed
        // once at cubit creation and cleared, so a later standalone /book
        // visit starts fresh (AC-5). It never travels in route params or
        // GoRouter extra (D-B4).
        final BookingPrefill prefill = serviceLocator<BookingPrefill>();
        final BookingCubit cubit = BookingCubit(
          serviceLocator<BookingGateway>(),
          attorneyId: prefill.attorneyId,
          attorneyName: prefill.attorneyName,
        );
        prefill.clear();
        return cubit;
      },
      child: const _BookingWizard(),
    );
  }
}

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
