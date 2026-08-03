import 'package:equatable/equatable.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/state/view_state.dart';
import '../domain/booking_category.dart';
import '../domain/booking_confirmation.dart';
import '../domain/booking_slot.dart';

/// The four steps of the consultation booking flow (approved SPEC/PLAN
/// Mermaid diagram): category → dateTime → review → success.
enum BookingStep { category, dateTime, review, success }

/// Lifecycle of the confirm operation, kept separate from [BookingStep] so
/// "the success step" and "submit succeeded" are never conflated: the review
/// step can carry idle/submitting/error, and only a succeeded confirm moves
/// to [BookingStep.success] with [BookingSubmitStatus.success].
enum BookingSubmitStatus { idle, submitting, success, error }

/// The in-progress (partial) booking carried in cubit state.
///
/// Approved SPEC AC#8: this cubit is the single owner of the partial — it is
/// never threaded through route parameters or GoRouter `extra`. Fields are
/// nullable because steps may not have been reached yet: [category] is chosen
/// in step 1, [slot] in step 2, [topic] is optional free text from step 1.
/// [BookingCubit.confirm] builds the gateway-bound [BookingRequest] from this
/// draft, trimming the topic at that boundary.
class BookingDraft extends Equatable {
  const BookingDraft({this.category, this.topic, this.slot});

  final BookingCategory? category;
  final String? topic;
  final BookingSlot? slot;

  @override
  List<Object?> get props => <Object?>[category, topic, slot];
}

/// Immutable state of the booking flow.
///
/// - [step] — the visible step the wizard shell renders.
/// - [draft] — the partial booking (never reset by step changes, see F3).
/// - [slots] — slot-load lifecycle on the date-time step, using the shared
///   [ViewState] vocabulary (loading / success / empty / error+retry).
/// - [submitStatus] — confirm-operation lifecycle (see [BookingSubmitStatus]).
/// - [submitError] — the failure from the last confirm attempt, cleared on
///   retry; only meaningful while [submitStatus] is [BookingSubmitStatus.error].
/// - [confirmation] — the synthetic confirmation returned by the gateway,
///   set when a confirm succeeds; the success step renders its reference id.
class BookingState extends Equatable {
  const BookingState({
    this.step = BookingStep.category,
    this.draft = const BookingDraft(),
    this.slots = const ViewEmpty<List<BookingSlot>>(),
    this.submitStatus = BookingSubmitStatus.idle,
    this.submitError,
    this.confirmation,
  });

  final BookingStep step;
  final BookingDraft draft;
  final ViewState<List<BookingSlot>> slots;
  final BookingSubmitStatus submitStatus;
  final AppError? submitError;
  final BookingConfirmation? confirmation;

  /// Sentinel distinguishing "not provided" from "explicitly null" so
  /// [submitError] can be cleared through copyWith.
  static const Object _unset = Object();

  BookingState copyWith({
    BookingStep? step,
    BookingDraft? draft,
    ViewState<List<BookingSlot>>? slots,
    BookingSubmitStatus? submitStatus,
    Object? submitError = _unset,
    BookingConfirmation? confirmation,
  }) {
    return BookingState(
      step: step ?? this.step,
      draft: draft ?? this.draft,
      slots: slots ?? this.slots,
      submitStatus: submitStatus ?? this.submitStatus,
      submitError: identical(submitError, _unset)
          ? this.submitError
          : submitError as AppError?,
      confirmation: confirmation ?? this.confirmation,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    step,
    draft,
    slots,
    submitStatus,
    submitError,
    confirmation,
  ];
}
