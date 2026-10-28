import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/booking/supabase_booking_api.dart';
import 'package:legalhub/features/booking/data/supabase_booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_category.dart';
import 'package:legalhub/features/booking/domain/booking_confirmation.dart';
import 'package:legalhub/features/booking/domain/booking_gateway.dart';
import 'package:legalhub/features/booking/domain/booking_request.dart';
import 'package:legalhub/features/booking/domain/booking_slot.dart';

void main() {
  group('SupabaseBookingGateway', () {
    late _StubBookingApi api;
    late BookingGateway gateway;

    setUp(() {
      api = _StubBookingApi();
      gateway = SupabaseBookingGateway(api);
    });

    test('is not local-only (the real backend path)', () {
      expect(gateway.isLocalOnly, isFalse);
    });

    test('fetchSlots maps rows with a local timestamp and duration', () async {
      api.slotRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'slot-1',
          'starts_at': '2026-11-10T09:00:00Z',
          'duration_minutes': 30,
        },
      ];

      final Result<List<BookingSlot>> result = await gateway.fetchSlots();

      final BookingSlot slot =
          (result as Success<List<BookingSlot>>).value.single;
      expect(slot.id, 'slot-1');
      expect(slot.startsAt, DateTime.parse('2026-11-10T09:00:00Z').toLocal());
      expect(slot.durationMinutes, 30);
    });

    test(
      'fetchSlots fails loudly on a malformed row (no silent slot)',
      () async {
        api.slotRows = <Map<String, dynamic>>[
          <String, dynamic>{'id': 'slot-1', 'duration_minutes': 30},
        ];

        final Result<List<BookingSlot>> result = await gateway.fetchSlots();

        final AppError error = (result as Failure<List<BookingSlot>>).error;
        expect(error.code, 'booking_slots_failed');
        expect(error.technicalMessage, 'Slot row has no starts_at');
      },
    );

    test('fetchSlots rejects a non-int duration', () async {
      api.slotRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'slot-1',
          'starts_at': '2026-11-10T09:00:00Z',
          'duration_minutes': '30',
        },
      ];

      final Result<List<BookingSlot>> result = await gateway.fetchSlots();

      expect(
        (result as Failure<List<BookingSlot>>).error.code,
        'booking_slots_failed',
      );
    });

    test('fetchSlots maps a denial to booking_slots_denied', () async {
      api.failure = const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.denied,
        message: 'permission denied',
      );

      final Result<List<BookingSlot>> result = await gateway.fetchSlots();

      final AppError error = (result as Failure<List<BookingSlot>>).error;
      expect(error.code, 'booking_slots_denied');
      expect(error.kind, AppErrorKind.denied);
    });

    test(
      'fetchSlots maps provider-unavailable to booking_slots_unavailable',
      () async {
        api.failure = const SupabaseBookingException(
          kind: SupabaseBookingFailureKind.providerUnavailable,
          message: 'connection refused',
        );

        final Result<List<BookingSlot>> result = await gateway.fetchSlots();

        final AppError error = (result as Failure<List<BookingSlot>>).error;
        expect(error.code, 'booking_slots_unavailable');
        expect(error.kind, AppErrorKind.unavailable);
      },
    );

    test('fetchSlots maps unknown to booking_slots_failed', () async {
      api.failure = const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.unknown,
        message: 'internal error',
      );

      final Result<List<BookingSlot>> result = await gateway.fetchSlots();

      expect(
        (result as Failure<List<BookingSlot>>).error.code,
        'booking_slots_failed',
      );
    });

    test(
      'confirm maps category, trims topic, and sends the attorney ref',
      () async {
        api.rowResult = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};
        const String attorneyId = '11111111-1111-4111-8111-111111111111';

        final Result<BookingConfirmation> result = await gateway.confirm(
          BookingRequest(
            category: BookingCategory.followUp,
            topic: '  merger question  ',
            slot: _slot,
            attorneyId: '  $attorneyId  ',
          ),
        );

        final BookingConfirmation confirmation =
            (result as Success<BookingConfirmation>).value;
        expect(confirmation.referenceId, 'LH-ABCDEF12');
        expect(api.bookCalls.single, <String, dynamic>{
          'slotId': 'slot-1',
          'category': 'follow_up',
          'topic': 'merger question',
          'attorneyRef': attorneyId,
        });
      },
    );

    test('confirm drops a synthetic attorney ref before the RPC', () async {
      api.rowResult = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};

      final Result<BookingConfirmation> result = await gateway.confirm(
        BookingRequest(
          category: BookingCategory.general,
          slot: _slot,
          attorneyId: 'atty-1',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(api.bookCalls.single['attorneyRef'], isNull);
    });

    test('confirm sends nulls for a blank topic and absent attorney', () async {
      api.rowResult = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};

      await gateway.confirm(
        BookingRequest(
          category: BookingCategory.general,
          topic: '   ',
          slot: _slot,
        ),
      );

      expect(api.bookCalls.single['topic'], isNull);
      expect(api.bookCalls.single['attorneyRef'], isNull);
    });

    test('confirm maps every category to its server value', () async {
      api.rowResult = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};

      for (final (BookingCategory category, String server)
          in <(BookingCategory, String)>[
            (BookingCategory.general, 'general'),
            (BookingCategory.followUp, 'follow_up'),
            (BookingCategory.urgent, 'urgent'),
          ]) {
        await gateway.confirm(BookingRequest(category: category, slot: _slot));
        expect(api.bookCalls.last['category'], server);
      }
    });

    test('confirm fails loudly when reference_id is missing', () async {
      api.rowResult = <String, dynamic>{'id': 'consultation-1'};

      final Result<BookingConfirmation> result = await gateway.confirm(
        BookingRequest(category: BookingCategory.general, slot: _slot),
      );

      final AppError error = (result as Failure<BookingConfirmation>).error;
      expect(error.code, 'booking_confirm_failed');
      expect(error.technicalMessage, 'Consultation row has no reference_id');
    });

    test('confirm maps a lost slot race to booking_slot_unavailable', () async {
      api.failure = const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.slotUnavailable,
        message: 'slot unavailable',
      );

      final Result<BookingConfirmation> result = await gateway.confirm(
        BookingRequest(category: BookingCategory.urgent, slot: _slot),
      );

      final AppError error = (result as Failure<BookingConfirmation>).error;
      expect(error.code, 'booking_slot_unavailable');
      expect(
        error.userMessage,
        'That time is no longer available. Choose another time.',
      );
    });

    test(
      'confirm maps a denial to booking_confirm_failed with denied kind',
      () async {
        api.failure = const SupabaseBookingException(
          kind: SupabaseBookingFailureKind.denied,
          message: 'permission denied',
        );

        final Result<BookingConfirmation> result = await gateway.confirm(
          BookingRequest(category: BookingCategory.general, slot: _slot),
        );

        final AppError error = (result as Failure<BookingConfirmation>).error;
        expect(error.code, 'booking_confirm_failed');
        expect(error.kind, AppErrorKind.denied);
      },
    );

    test('confirm maps provider-unavailable with the retryable kind', () async {
      api.failure = const SupabaseBookingException(
        kind: SupabaseBookingFailureKind.providerUnavailable,
        message: 'connection refused',
      );

      final Result<BookingConfirmation> result = await gateway.confirm(
        BookingRequest(category: BookingCategory.general, slot: _slot),
      );

      final AppError error = (result as Failure<BookingConfirmation>).error;
      expect(error.code, 'booking_confirm_failed');
      expect(error.kind, AppErrorKind.unavailable);
    });

    test(
      'failure messages never carry the topic, attorney id, or reference',
      () async {
        api.failure = const SupabaseBookingException(
          kind: SupabaseBookingFailureKind.unknown,
          message: 'internal error',
        );

        final Result<BookingConfirmation> result = await gateway.confirm(
          BookingRequest(
            category: BookingCategory.urgent,
            topic: 'Secret merger claim',
            slot: _slot,
            attorneyId: 'atty-secret',
          ),
        );

        final AppError error = (result as Failure<BookingConfirmation>).error;
        expect(error.userMessage, isNot(contains('Secret merger claim')));
        expect(error.userMessage, isNot(contains('atty-secret')));
        expect(error.technicalMessage, isNot(contains('Secret merger claim')));
        expect(error.technicalMessage, isNot(contains('atty-secret')));
        expect(error.technicalMessage, isNot(contains('LH-')));
      },
    );

    test(
      'a slotless request is a generic confirm failure, never a crash',
      () async {
        final Result<BookingConfirmation> result = await gateway.confirm(
          const BookingRequest(category: BookingCategory.general),
        );

        expect(
          (result as Failure<BookingConfirmation>).error.code,
          'booking_confirm_failed',
        );
        expect(api.bookCalls, isEmpty);
      },
    );
  });
}

final BookingSlot _slot = BookingSlot(
  id: 'slot-1',
  startsAt: DateTime(2026, 11, 10, 9),
  durationMinutes: 30,
);

class _StubBookingApi implements SupabaseBookingApi {
  List<Map<String, dynamic>> slotRows = <Map<String, dynamic>>[];
  Map<String, dynamic> rowResult = <String, dynamic>{};
  SupabaseBookingException? failure;

  final List<Map<String, dynamic>> bookCalls = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchSlots() async {
    final SupabaseBookingException? error = failure;
    if (error != null) {
      throw error;
    }
    return slotRows;
  }

  @override
  Future<Map<String, dynamic>> bookConsultation({
    required String slotId,
    required String category,
    String? topic,
    String? attorneyRef,
  }) async {
    bookCalls.add(<String, dynamic>{
      'slotId': slotId,
      'category': category,
      'topic': topic,
      'attorneyRef': attorneyRef,
    });
    final SupabaseBookingException? error = failure;
    if (error != null) {
      throw error;
    }
    return rowResult;
  }
}
