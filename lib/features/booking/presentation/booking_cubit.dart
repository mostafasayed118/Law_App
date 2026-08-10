import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../domain/booking_category.dart';
import '../domain/booking_confirmation.dart';
import '../domain/booking_gateway.dart';
import '../domain/booking_request.dart';
import '../domain/booking_slot.dart';
import 'booking_state.dart';

/// Owns the 4-step consultation booking state machine (approved SPEC/PLAN):
/// category → dateTime → review → success, with one-step [back] edges, a
/// submitting intermediate state during confirm, and the review→category
/// "Edit category" affordance — an explicit addition beyond the approved
/// diagram, ratified on review (see [editCategory]).
///
/// This cubit is the single owner of the partial booking (approved SPEC
/// AC#8): the draft lives in [BookingState.draft] and is NEVER threaded
/// through route parameters or GoRouter `extra`. The forgot-password flow
/// used `extra` because it had one route per step; this flow has a single
/// `/book` route with an internal step switcher (owner ruling G1), so no
/// routing payload exists at all. Citing that precedent here is an honesty
/// note only ("no URL params"), not a mechanism.
///
/// Widgets render [BookingState] and dispatch intents; they never mutate the
/// draft or call the gateway directly.
class BookingCubit extends Cubit<BookingState> {
  /// [attorneyId]/[attorneyName] seed the draft from the discovery
  /// profile prefill (Phase 6 D-A3); both default to null so the
  /// standalone flow is unchanged (AC-5).
  BookingCubit(this._gateway, {String? attorneyId, String? attorneyName})
    : super(
        BookingState(
          draft: BookingDraft(
            attorneyId: attorneyId,
            attorneyName: attorneyName,
          ),
        ),
      );

  final BookingGateway _gateway;

  void selectCategory(BookingCategory category) {
    if (isClosed || state.step != BookingStep.category) {
      return;
    }
    final BookingDraft draft = state.draft;
    emit(
      state.copyWith(
        draft: BookingDraft(
          category: category,
          topic: draft.topic,
          slot: draft.slot,
          attorneyId: draft.attorneyId,
          attorneyName: draft.attorneyName,
        ),
      ),
    );
  }

  /// Stores the free-text topic verbatim (no trim here — trimming happens at
  /// the gateway boundary in [confirm] so typing is never fought).
  void updateTopic(String topic) {
    if (isClosed || state.step != BookingStep.category) {
      return;
    }
    final BookingDraft draft = state.draft;
    emit(
      state.copyWith(
        draft: BookingDraft(
          category: draft.category,
          topic: topic,
          slot: draft.slot,
          attorneyId: draft.attorneyId,
          attorneyName: draft.attorneyName,
        ),
      ),
    );
  }

  /// Step-1 → step-2: advances only when a category is selected, then loads
  /// the synthetic slots into [BookingState.slots]. A response that lands
  /// after the user has left the date-time step is dropped (stale guard).
  Future<void> continueFromCategory() async {
    if (isClosed || state.step != BookingStep.category) {
      return;
    }
    if (state.draft.category == null) {
      return;
    }
    emit(
      state.copyWith(
        step: BookingStep.dateTime,
        slots: const ViewLoading<List<BookingSlot>>(),
        submitStatus: BookingSubmitStatus.idle,
      ),
    );
    await _loadSlots();
  }

  /// Re-runs the slot fetch from the date-time step (the slot-error arm's
  /// retry). Only fires while the date-time step is visible AND the previous
  /// load failed; a tap during an in-flight reload no-ops (the loading state
  /// replaced the error state).
  Future<void> retryLoadSlots() async {
    if (isClosed ||
        state.step != BookingStep.dateTime ||
        state.slots is! ViewError<List<BookingSlot>>) {
      return;
    }
    emit(state.copyWith(slots: const ViewLoading<List<BookingSlot>>()));
    await _loadSlots();
  }

  /// Shared slot-fetch tail for [continueFromCategory] and [retryLoadSlots]:
  /// maps the gateway result into [BookingState.slots]. A response that
  /// lands after the user has left the date-time step is dropped (stale
  /// guard).
  Future<void> _loadSlots() async {
    final Result<List<BookingSlot>> result = await _gateway.fetchSlots();
    if (isClosed || state.step != BookingStep.dateTime) {
      return;
    }
    switch (result) {
      case Success<List<BookingSlot>>(value: final List<BookingSlot> slots):
        emit(
          state.copyWith(
            slots: slots.isEmpty
                ? const ViewEmpty<List<BookingSlot>>()
                : ViewSuccess<List<BookingSlot>>(slots),
          ),
        );
      case Failure<List<BookingSlot>>(error: final AppError error):
        emit(state.copyWith(slots: ViewError<List<BookingSlot>>(error)));
    }
  }

  void selectSlot(BookingSlot slot) {
    if (isClosed || state.step != BookingStep.dateTime) {
      return;
    }
    final BookingDraft draft = state.draft;
    emit(
      state.copyWith(
        draft: BookingDraft(
          category: draft.category,
          topic: draft.topic,
          slot: slot,
          attorneyId: draft.attorneyId,
          attorneyName: draft.attorneyName,
        ),
      ),
    );
  }

  /// Step-2 → step-3: advances only when a slot is selected.
  void continueFromDateTime() {
    if (isClosed || state.step != BookingStep.dateTime) {
      return;
    }
    if (state.draft.slot == null) {
      return;
    }
    emit(state.copyWith(step: BookingStep.review));
  }

  /// Moves one step back (review → dateTime → category). No-op on the
  /// category step (the wizard shell's own back button exits to home) and on
  /// the terminal success step.
  ///
  /// F3: the existing [BookingState.draft] is copied forward — the step
  /// changes, the draft fields are retained. The state is never rebuilt from
  /// a fresh draft, so the selected slot (review → dateTime) and the chosen
  /// category + topic text (dateTime → category) survive. The submit
  /// lifecycle resets to idle because it belongs to the last confirm attempt,
  /// not to the draft.
  void back() {
    if (isClosed) {
      return;
    }
    final BookingStep? previous = switch (state.step) {
      BookingStep.dateTime => BookingStep.category,
      BookingStep.review => BookingStep.dateTime,
      BookingStep.category || BookingStep.success => null,
    };
    if (previous == null) {
      return;
    }
    emit(
      BookingState(
        step: previous,
        draft: state.draft,
        slots: state.slots,
        submitStatus: BookingSubmitStatus.idle,
      ),
    );
  }

  /// The review → category "Edit category" affordance.
  ///
  /// NOTE: this direct review→category jump is an ADDITION beyond the
  /// approved Mermaid diagram (which specified one-step back() edges only)
  /// and beyond the TASKS list. It is a review-screen convenience that
  /// re-picks the category without losing the rest of the draft (the
  /// selected slot is kept). Ratified by the owner on review — recorded
  /// here as an explicit addition, not a spec edge.
  void editCategory() {
    if (isClosed || state.step != BookingStep.review) {
      return;
    }
    emit(
      BookingState(
        step: BookingStep.category,
        draft: state.draft,
        slots: state.slots,
        submitStatus: BookingSubmitStatus.idle,
      ),
    );
  }

  /// Step-3 → step-4: awaits the gateway and maps the result. A success
  /// moves to the success step with the confirmation; a failure stays on the
  /// review step with the error surfaced via [BookingState.submitError] and
  /// the draft intact (no data loss), so the user can retry.
  ///
  /// Duplicate-confirm guard: confirm() is ignored while a submit is in
  /// flight or already succeeded — but an errored submit is re-confirmable.
  /// A response that lands after the user has left the review step or after
  /// a newer attempt started is dropped (stale guard).
  Future<void> confirm() async {
    if (isClosed) {
      return;
    }
    final BookingState current = state;
    if (current.step != BookingStep.review) {
      return;
    }
    if (current.submitStatus == BookingSubmitStatus.submitting ||
        current.submitStatus == BookingSubmitStatus.success) {
      return;
    }
    final BookingDraft draft = current.draft;
    final BookingCategory? category = draft.category;
    final BookingSlot? slot = draft.slot;
    if (category == null || slot == null) {
      return;
    }
    emit(
      current.copyWith(
        submitStatus: BookingSubmitStatus.submitting,
        submitError: null,
      ),
    );
    final Result<BookingConfirmation> result = await _gateway.confirm(
      BookingRequest(
        category: category,
        topic: draft.topic?.trim(),
        slot: slot,
        attorneyId: draft.attorneyId,
      ),
    );
    if (isClosed) {
      return;
    }
    final BookingState latest = state;
    if (latest.step != BookingStep.review ||
        latest.submitStatus != BookingSubmitStatus.submitting) {
      return;
    }
    switch (result) {
      case Success<BookingConfirmation>(value: final BookingConfirmation c):
        emit(
          BookingState(
            step: BookingStep.success,
            draft: latest.draft,
            slots: latest.slots,
            submitStatus: BookingSubmitStatus.success,
            confirmation: c,
          ),
        );
      case Failure<BookingConfirmation>(error: final AppError error):
        emit(
          latest.copyWith(
            submitStatus: BookingSubmitStatus.error,
            submitError: error,
          ),
        );
    }
  }
}
