import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/booking/data/fake_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_confirmation.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_prefill.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';
import 'package:legalhub/features/booking/domain/booking_slot.dart';
import 'package:legalhub/features/booking/presentation/booking_screen.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Gateway whose slot load succeeds but whose confirm always fails, so the
/// review-step error surface (AC-4) is reachable in a widget test.
class _FailingConfirmGateway implements BookingGateway {
  @override
  Future<Result<List<BookingSlot>>> fetchSlots() async {
    return Result<List<BookingSlot>>.success(FakeBookingGateway.syntheticSlots);
  }

  @override
  Future<Result<BookingConfirmation>> confirm(BookingRequest request) async {
    return Result<BookingConfirmation>.failure(
      const AppError(code: 'booking.unavailable', userMessage: 'Unavailable'),
    );
  }
}

void main() {
  tearDown(resetServiceLocator);

  Future<void> pumpBooking(WidgetTester tester) async {
    configureDependencies();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BookingScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectCategory(WidgetTester tester) async {
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
  }

  Future<void> goToDateTime(WidgetTester tester) async {
    await selectCategory(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> goToReview(WidgetTester tester) async {
    await goToDateTime(tester);
    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  group('booking wizard (Phase 5 slice 5.1)', () {
    testWidgets('starts on the category step with Continue disabled', (
      tester,
    ) async {
      await pumpBooking(tester);

      expect(find.text('Consultation type'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Follow-up'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      // No category selected yet -> the step cannot advance (AC-2).
      final ElevatedButton continueButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('shows the local-only demo note on the category step', (
      tester,
    ) async {
      await pumpBooking(tester);

      // D-B3/D-B6: the copy must never imply a backend promise or payment.
      expect(
        find.text('Demo mode — no consultation is actually booked or sent.'),
        findsOneWidget,
      );
    });

    testWidgets('a category selection enables Continue and loads slots', (
      tester,
    ) async {
      await pumpBooking(tester);
      await goToDateTime(tester);

      // The date-time step renders the fake's deterministic slot list
      // (AC-3 success path): slot-1 at 9:00 AM.
      expect(find.text('Select date & time'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('selecting a slot and continuing shows the review summary', (
      tester,
    ) async {
      await pumpBooking(tester);
      await goToReview(tester);

      expect(find.text('Review your booking'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Not specified'), findsOneWidget); // topic not set
    });

    testWidgets('confirm moves to the success step with the reference id', (
      tester,
    ) async {
      await pumpBooking(tester);
      await goToReview(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Reference: LH-DEMO-0001'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('back preserves the draft (F3)', (tester) async {
      await pumpBooking(tester);
      await goToReview(tester);

      // review -> dateTime: the selected slot survives.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Select date & time'), findsOneWidget);
      expect(find.text('9:00 AM'), findsOneWidget);

      // dateTime -> category: the chosen category survives (selection state
      // is re-derivable from the draft, which is preserved).
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Consultation type'), findsOneWidget);
    });

    testWidgets('editCategory jumps from review back to the category step', (
      tester,
    ) async {
      await pumpBooking(tester);
      await goToReview(tester);

      await tester.tap(find.text('Edit category'));
      await tester.pumpAndSettle();

      expect(find.text('Consultation type'), findsOneWidget);
    });

    testWidgets('topic text typed on step 1 survives to the review step', (
      tester,
    ) async {
      await pumpBooking(tester);
      await tester.enterText(find.byType(TextFormField), 'Merger question');
      await tester.pumpAndSettle();
      await goToReview(tester);

      expect(find.text('Merger question'), findsOneWidget);
    });

    testWidgets('surfaces a localized failure and stays on review (AC-4)', (
      tester,
    ) async {
      // Register the failing gateway before configureDependencies so the
      // idempotent guard keeps it as the registered seam.
      serviceLocator.registerLazySingleton<BookingGateway>(
        _FailingConfirmGateway.new,
      );
      await pumpBooking(tester);
      await goToReview(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to confirm. Please try again.'), findsOneWidget);
      // The draft is intact and the user stays on review to retry.
      expect(find.text('Review your booking'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets(
      'seeds the draft from the prefill holder and clears it (D-A3/AC-5)',
      (tester) async {
        configureDependencies();
        serviceLocator<BookingPrefill>()
          ..attorneyId = 'atty-1'
          ..attorneyName = 'Layla Mansour';

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BookingScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // The category step confirms the prefill reached the draft.
        expect(find.text('Booking with Layla Mansour'), findsOneWidget);

        // Consumed at cubit creation: a later standalone visit starts
        // fresh (AC-5).
        expect(serviceLocator<BookingPrefill>().attorneyId, isNull);
        expect(serviceLocator<BookingPrefill>().attorneyName, isNull);
      },
    );
  });
}
