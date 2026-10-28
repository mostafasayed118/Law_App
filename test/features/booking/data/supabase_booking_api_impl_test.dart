import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/booking/data/supabase_booking_api.dart';
import 'package:legalhub/features/booking/data/supabase_booking_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseBookingApiImpl', () {
    late List<String> tableCalls;
    late List<Map<String, dynamic>> tableRows;
    late PostgrestException? tableError;
    late Object? tableObjectError;
    late List<String> rpcCalls;
    late Object? rpcData;
    late PostgrestException? rpcError;
    late SupabaseBookingApiImpl api;

    setUp(() {
      tableCalls = <String>[];
      tableRows = <Map<String, dynamic>>[];
      tableError = null;
      tableObjectError = null;
      rpcCalls = <String>[];
      rpcData = null;
      rpcError = null;
      api = SupabaseBookingApiImpl(
        (String table, String columns) async {
          tableCalls.add('$table:$columns');
          final Object? objectError = tableObjectError;
          if (objectError != null) {
            throw objectError;
          }
          final PostgrestException? error = tableError;
          if (error != null) {
            throw error;
          }
          return tableRows;
        },
        rpcCaller: (String function, Map<String, dynamic> params) async {
          // The recorded shape pins the RPC contract: function name + every
          // named param (nulls included) in call order.
          rpcCalls.add(
            '$function:${params.keys.join(',')}:${params.values.join(',')}',
          );
          final PostgrestException? error = rpcError;
          if (error != null) {
            throw error;
          }
          return PostgrestResponse<dynamic>(data: rpcData, count: 0);
        },
      );
    });

    test('fetchSlots selects consultation_slots with the VO columns', () async {
      tableRows = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'slot-1'},
      ];

      final List<Map<String, dynamic>> rows = await api.fetchSlots();

      expect(rows, hasLength(1));
      expect(tableCalls, <String>[
        'consultation_slots:id, starts_at, duration_minutes',
      ]);
    });

    test('fetchSlots maps a table denial to the denied kind', () async {
      tableError = const PostgrestException(message: 'permission denied');

      await expectLater(
        api.fetchSlots(),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.denied,
          ),
        ),
      );
    });

    test(
      'fetchSlots maps a non-Postgrest failure to providerUnavailable',
      () async {
        tableObjectError = Exception('transport down');

        await expectLater(
          api.fetchSlots(),
          throwsA(
            isA<SupabaseBookingException>().having(
              (e) => e.kind,
              'kind',
              SupabaseBookingFailureKind.providerUnavailable,
            ),
          ),
        );
      },
    );

    test('bookConsultation calls the RPC with all four named params', () async {
      rpcData = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};

      final Map<String, dynamic> row = await api.bookConsultation(
        slotId: 'slot-1',
        category: 'follow_up',
        topic: 'Merger question',
        attorneyRef: 'atty-1',
      );

      expect(row['reference_id'], 'LH-ABCDEF12');
      expect(rpcCalls, <String>[
        'book_consultation:p_slot_id,p_category,p_topic,p_attorney_ref:'
            'slot-1,follow_up,Merger question,atty-1',
      ]);
    });

    test(
      'bookConsultation sends explicit nulls for absent optional fields',
      () async {
        rpcData = <String, dynamic>{'reference_id': 'LH-ABCDEF12'};

        await api.bookConsultation(slotId: 'slot-1', category: 'general');

        // The RPC defaults both to null; the client sends the keys explicitly
        // so the param shape never drifts between the filled and empty paths.
        expect(rpcCalls, <String>[
          'book_consultation:p_slot_id,p_category,p_topic,p_attorney_ref:'
              'slot-1,general,null,null',
        ]);
      },
    );

    test('maps the 23514 validation SQLSTATE to the validation kind', () async {
      rpcError = const PostgrestException(
        message: 'invalid consultation category',
        code: '23514',
      );

      await expectLater(
        api.bookConsultation(slotId: 'slot-1', category: 'general'),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.validation,
          ),
        ),
      );
    });

    test('maps the 23505 unique violation to slotUnavailable', () async {
      rpcError = const PostgrestException(
        message: 'slot unavailable',
        code: '23505',
      );

      await expectLater(
        api.bookConsultation(slotId: 'slot-1', category: 'general'),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.slotUnavailable,
          ),
        ),
      );
    });

    test('maps the in-function auth gate to the denied kind', () async {
      rpcError = const PostgrestException(message: 'permission denied');

      await expectLater(
        api.bookConsultation(slotId: 'slot-1', category: 'general'),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.denied,
          ),
        ),
      );
    });

    test('an unrecognized RPC failure is unknown (never a denial)', () async {
      rpcError = const PostgrestException(message: 'connection reset by peer');

      await expectLater(
        api.bookConsultation(slotId: 'slot-1', category: 'general'),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.unknown,
          ),
        ),
      );
    });

    test(
      'a non-map RPC response is a typed unknown, never a cast error',
      () async {
        rpcData = 'slot-1';

        await expectLater(
          api.bookConsultation(slotId: 'slot-1', category: 'general'),
          throwsA(
            isA<SupabaseBookingException>().having(
              (e) => e.kind,
              'kind',
              SupabaseBookingFailureKind.unknown,
            ),
          ),
        );
      },
    );

    test('a non-Postgrest RPC failure is providerUnavailable', () async {
      api = SupabaseBookingApiImpl(
        (String table, String columns) async => tableRows,
        rpcCaller: (String function, Map<String, dynamic> params) async {
          throw Exception('transport down');
        },
      );

      await expectLater(
        api.bookConsultation(slotId: 'slot-1', category: 'general'),
        throwsA(
          isA<SupabaseBookingException>().having(
            (e) => e.kind,
            'kind',
            SupabaseBookingFailureKind.providerUnavailable,
          ),
        ),
      );
    });
  });
}
