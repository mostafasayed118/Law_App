import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/data/billing/supabase_payment_api.dart';
import 'package:legalhub/data/billing/supabase_payment_api_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabasePaymentApiImpl', () {
    late List<(String, Map<String, dynamic>)> functionCalls;
    late List<(String, Map<String, dynamic>)> rpcCalls;
    late Object? functionResult;
    late Object? functionError;
    late Object? rpcResult;
    late Object? rpcError;
    late SupabasePaymentApiImpl api;

    setUp(() {
      functionCalls = <(String, Map<String, dynamic>)>[];
      rpcCalls = <(String, Map<String, dynamic>)>[];
      functionResult = null;
      functionError = null;
      rpcResult = null;
      rpcError = null;
      api = SupabasePaymentApiImpl(
        (String function, Map<String, dynamic> body) async {
          functionCalls.add((function, body));
          final Object? error = functionError;
          if (error != null) {
            throw error;
          }
          return functionResult;
        },
        (String function, Map<String, dynamic> params) async {
          rpcCalls.add((function, params));
          final Object? error = rpcError;
          if (error != null) {
            throw error;
          }
          return rpcResult;
        },
      );
    });

    test('initiate invokes paymob-initiate with the invoice_id body', () async {
      functionResult = <String, dynamic>{'payment_id': 'p-1'};

      final Map<String, dynamic> result = await api.initiate('invoice-1');

      expect(result, <String, dynamic>{'payment_id': 'p-1'});
      expect(functionCalls, hasLength(1));
      expect(functionCalls.single.$1, 'paymob-initiate');
      expect(functionCalls.single.$2, <String, dynamic>{
        'invoice_id': 'invoice-1',
      });
    });

    test('fetchStatus invokes the status RPC with p_invoice_id', () async {
      rpcResult = <String, dynamic>{'payment_id': 'p-1'};

      final Map<String, dynamic>? result = await api.fetchStatus('invoice-1');

      expect(result, <String, dynamic>{'payment_id': 'p-1'});
      expect(rpcCalls, hasLength(1));
      expect(rpcCalls.single.$1, 'get_invoice_payment_status');
      expect(rpcCalls.single.$2, <String, dynamic>{
        'p_invoice_id': 'invoice-1',
      });
    });

    test('fetchStatus returns null when the invoice has no attempt', () async {
      rpcResult = null;

      expect(await api.fetchStatus('invoice-1'), isNull);
    });

    test('a non-map initiate response is a typed unknown failure', () async {
      functionResult = <Object?>['not', 'a', 'map'];

      await expectLater(
        api.initiate('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.unknown,
          ),
        ),
      );
    });

    test('a non-map status response is a typed unknown failure', () async {
      rpcResult = 'not-a-map';

      await expectLater(
        api.fetchStatus('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.unknown,
          ),
        ),
      );
    });

    test('maps function 401/403 to denied', () async {
      for (final int status in <int>[401, 403]) {
        functionError = FunctionException(status: status);
        await expectLater(
          api.initiate('invoice-1'),
          throwsA(
            isA<SupabasePaymentException>().having(
              (SupabasePaymentException e) => e.kind,
              'kind',
              SupabasePaymentFailureKind.denied,
            ),
          ),
        );
      }
    });

    test('maps function transport/5xx to providerUnavailable', () async {
      for (final int status in <int>[0, 500, 502, 503]) {
        functionError = FunctionException(status: status);
        await expectLater(
          api.initiate('invoice-1'),
          throwsA(
            isA<SupabasePaymentException>().having(
              (SupabasePaymentException e) => e.kind,
              'kind',
              SupabasePaymentFailureKind.providerUnavailable,
            ),
          ),
        );
      }
    });

    test('maps other function 4xx to unknown', () async {
      functionError = const FunctionException(status: 400);

      await expectLater(
        api.initiate('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.unknown,
          ),
        ),
      );
    });

    test('maps an RPC denial to denied', () async {
      rpcError = const PostgrestException(message: 'permission denied');

      await expectLater(
        api.fetchStatus('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.denied,
          ),
        ),
      );
    });

    test('maps a non-denial RPC error to unknown', () async {
      rpcError = const PostgrestException(message: 'unexpected response');

      await expectLater(
        api.fetchStatus('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.unknown,
          ),
        ),
      );
    });

    test('maps a transport failure to providerUnavailable', () async {
      rpcError = Exception('network down');

      await expectLater(
        api.fetchStatus('invoice-1'),
        throwsA(
          isA<SupabasePaymentException>().having(
            (SupabasePaymentException e) => e.kind,
            'kind',
            SupabasePaymentFailureKind.providerUnavailable,
          ),
        ),
      );
    });
  });
}
