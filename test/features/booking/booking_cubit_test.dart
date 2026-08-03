import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/booking/domain/booking_category.dart';
import 'package:legalhub/features/booking/domain/booking_confirmation.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';
import 'package:legalhub/features/booking/domain/booking_slot.dart';
import 'package:legalhub/features/booking/presentation/booking_cubit.dart';
import 'package:legalhub/features/booking/presentation/booking_state.dart';

void main() {
  late _StubBookingGateway gateway;

  setUp(() {
    gateway = _StubBookingGateway();
  });

  group('BookingCubit', () {
    test('starts on the category step with an empty draft and idle submit', () {
      final BookingCubit cubit = BookingCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.step, BookingStep.category);
      expect(cubit.state.draft, BookingDraft());
      expect(cubit.state.slots, const ViewEmpty<List<BookingSlot>>());
      expect(cubit.state.submitStatus, BookingSubmitStatus.idle);
      expect(cubit.state.submitError, isNull);
    });

    test('selectCategory stores the category in the draft', () {
      final BookingCubit cubit = BookingCubit(gateway);
      addTearDown(cubit.close);

      cubit.selectCategory(BookingCategory.urgent);

      expect(cubit.state.draft.category, BookingCategory.urgent);
      expect(cubit.state.step, BookingStep.category);
    });

    test('updateTopic stores the topic text verbatim', () {
      final BookingCubit cubit = BookingCubit(gateway);
      addTearDown(cubit.close);

      cubit.updateTopic('  estate matter  ');

      expect(cubit.state.draft.topic, '  estate matter  ');
    });

    blocTest<BookingCubit, BookingState>(
      'continueFromCategory advances to date-time and loads slots',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'continueFromCategory is ignored without a category',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) => cubit.continueFromCategory(),
      expect: () => <BookingState>[],
      verify: (_) => expect(gateway.fetchSlotsCalls, 0),
    );

    blocTest<BookingCubit, BookingState>(
      'continueFromCategory surfaces an empty slot list as ViewEmpty',
      setUp: () => gateway = _StubBookingGateway(slots: const <BookingSlot>[]),
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewEmpty<List<BookingSlot>>(),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'continueFromCategory surfaces a slot-load failure as ViewError',
      setUp: () => gateway = _StubBookingGateway(
        slotsResult: Result<List<BookingSlot>>.failure(_slotsFailure),
      ),
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewError<List<BookingSlot>>(_slotsFailure),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'selectSlot then continueFromDateTime advances to review',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'continueFromDateTime is ignored without a slot',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.continueFromDateTime();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'F3: back from date-time to category preserves category and topic',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.followUp);
        cubit.updateTopic('child custody');
        await cubit.continueFromCategory();
        cubit.back();
      },
      expect: () => <BookingState>[
        BookingState(
          draft: const BookingDraft(category: BookingCategory.followUp),
        ),
        BookingState(
          draft: const BookingDraft(
            category: BookingCategory.followUp,
            topic: 'child custody',
          ),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.followUp,
            topic: 'child custody',
          ),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.followUp,
            topic: 'child custody',
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.category,
          draft: BookingDraft(
            category: BookingCategory.followUp,
            topic: 'child custody',
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'F3: back from review to date-time preserves the selected slot',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        cubit.updateTopic('estate matter');
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        cubit.back();
      },
      expect: () => <BookingState>[
        BookingState(
          draft: const BookingDraft(category: BookingCategory.general),
        ),
        BookingState(
          draft: const BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'editCategory from review preserves the draft including the slot',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        cubit.updateTopic('estate matter');
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        cubit.editCategory();
      },
      expect: () => <BookingState>[
        BookingState(
          draft: const BookingDraft(category: BookingCategory.general),
        ),
        BookingState(
          draft: const BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.category,
          draft: BookingDraft(
            category: BookingCategory.general,
            topic: 'estate matter',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
    );

    blocTest<BookingCubit, BookingState>(
      'confirm moves to the success step with the confirmation, draft intact',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.urgent);
        cubit.updateTopic('  urgent matter  ');
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        await cubit.confirm();
      },
      expect: () => <BookingState>[
        BookingState(
          draft: const BookingDraft(category: BookingCategory.urgent),
        ),
        BookingState(
          draft: const BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
          ),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
          ),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.success,
          draft: BookingDraft(
            category: BookingCategory.urgent,
            topic: '  urgent matter  ',
            slot: _slot,
          ),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.success,
          confirmation: _confirmation,
        ),
      ],
      verify: (_) {
        // The gateway received a BookingRequest built from the draft, with the
        // topic trimmed at the boundary.
        expect(gateway.confirmCalls, 1);
        expect(gateway.received?.category, BookingCategory.urgent);
        expect(gateway.received?.topic, 'urgent matter');
        expect(gateway.received?.slot, _slot);
      },
    );

    blocTest<BookingCubit, BookingState>(
      'confirm failure stays on review with the error, draft intact, retry works',
      setUp: () => gateway = _StubBookingGateway(
        confirmResults: <Result<BookingConfirmation>>[
          Result<BookingConfirmation>.failure(_confirmFailure),
          Result<BookingConfirmation>.success(_confirmation),
        ],
      ),
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        await cubit.confirm();
        await cubit.confirm();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.error,
          submitError: _confirmFailure,
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.success,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.success,
          confirmation: _confirmation,
        ),
      ],
      verify: (_) => expect(gateway.confirmCalls, 2),
    );

    blocTest<BookingCubit, BookingState>(
      'duplicate confirm while submitting is ignored',
      setUp: () => gateway = _StubBookingGateway.withCompleter(),
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        final Future<void> first = cubit.confirm();
        await cubit.confirm();
        gateway.completer!.complete(
          Result<BookingConfirmation>.success(_confirmation),
        );
        await first;
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.success,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.success,
          confirmation: _confirmation,
        ),
      ],
      verify: (_) => expect(gateway.confirmCalls, 1),
    );

    blocTest<BookingCubit, BookingState>(
      'duplicate confirm after success is ignored',
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        await cubit.confirm();
        await cubit.confirm();
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.success,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.success,
          confirmation: _confirmation,
        ),
      ],
      verify: (_) => expect(gateway.confirmCalls, 1),
    );

    blocTest<BookingCubit, BookingState>(
      'confirm drops a stale response after backing away mid-flight',
      setUp: () => gateway = _StubBookingGateway.withCompleter(),
      build: () => BookingCubit(gateway),
      act: (BookingCubit cubit) async {
        cubit.selectCategory(BookingCategory.general);
        await cubit.continueFromCategory();
        cubit.selectSlot(_slot);
        cubit.continueFromDateTime();
        final Future<void> confirmFuture = cubit.confirm();
        cubit.back();
        gateway.completer!.complete(
          Result<BookingConfirmation>.success(_confirmation),
        );
        await confirmFuture;
      },
      expect: () => <BookingState>[
        BookingState(draft: BookingDraft(category: BookingCategory.general)),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewLoading<List<BookingSlot>>(),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
        BookingState(
          step: BookingStep.review,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
          submitStatus: BookingSubmitStatus.submitting,
        ),
        BookingState(
          step: BookingStep.dateTime,
          draft: BookingDraft(category: BookingCategory.general, slot: _slot),
          slots: ViewSuccess<List<BookingSlot>>(_slots),
        ),
      ],
      verify: (_) => expect(gateway.confirmCalls, 1),
    );
  });
}

final DateTime _startsAt = DateTime(2026, 8, 10, 9);
final BookingSlot _slot = BookingSlot(
  id: 'slot-1',
  startsAt: _startsAt,
  durationMinutes: 30,
);
final List<BookingSlot> _slots = <BookingSlot>[_slot];

const BookingConfirmation _confirmation = BookingConfirmation(
  referenceId: 'LH-DEMO-TEST',
);

final AppError _slotsFailure = AppError(
  code: 'slots_failed',
  userMessage: 'Could not load slots',
);

final AppError _confirmFailure = AppError(
  code: 'confirm_failed',
  userMessage: 'Could not confirm the booking',
);

/// Hand-rolled gateway stub: fixed slot result by default, queue of confirm
/// results, or a Completer for in-flight tests.
class _StubBookingGateway implements BookingGateway {
  _StubBookingGateway({
    List<BookingSlot>? slots,
    Result<List<BookingSlot>>? slotsResult,
    List<Result<BookingConfirmation>>? confirmResults,
  }) : slotsResult =
           slotsResult ?? Result<List<BookingSlot>>.success(slots ?? _slots) {
    this.confirmResults =
        confirmResults ??
        <Result<BookingConfirmation>>[
          Result<BookingConfirmation>.success(_confirmation),
        ];
  }

  _StubBookingGateway.withCompleter()
    : slotsResult = Result<List<BookingSlot>>.success(_slots),
      confirmResults = null {
    completer = Completer<Result<BookingConfirmation>>();
  }

  final Result<List<BookingSlot>> slotsResult;
  List<Result<BookingConfirmation>>? confirmResults;
  Completer<Result<BookingConfirmation>>? completer;
  int fetchSlotsCalls = 0;
  int confirmCalls = 0;
  BookingRequest? received;

  @override
  Future<Result<List<BookingSlot>>> fetchSlots() async {
    fetchSlotsCalls += 1;
    return slotsResult;
  }

  @override
  Future<Result<BookingConfirmation>> confirm(BookingRequest request) {
    confirmCalls += 1;
    received = request;
    if (completer != null) {
      return completer!.future;
    }
    return Future<Result<BookingConfirmation>>.value(
      confirmResults!.removeAt(0),
    );
  }
}
