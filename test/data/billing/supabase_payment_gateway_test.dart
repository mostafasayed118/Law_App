import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/billing/supabase_payment_api.dart';
import 'package:legalhub/data/billing/supabase_payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_session.dart';
import 'package:legalhub/features/billing/domain/payment_status.dart';

class _StubPaymentApi implements SupabasePaymentApi {
  Map<String, dynamic> initiateResult = <String, dynamic>{};
  SupabasePaymentException? initiateError;
  Map<String, dynamic>? statusResult;
  SupabasePaymentException? statusError;

  @override
  Future<Map<String, dynamic>> initiate(String invoiceId) async {
    if (initiateError != null) {
      throw initiateError!;
    }
    return initiateResult;
  }

  @override
  Future<Map<String, dynamic>?> fetchStatus(String invoiceId) async {
    if (statusError != null) {
      throw statusError!;
    }
    return statusResult;
  }
}

Map<String, dynamic> _initiatePayload({
  String paymentId = 'pay-1',
  String status = 'pending',
  Object? checkoutUrl =
      'https://accept.paymob.com/unifiedcheckout/?publicKey=pub',
  Object? amountCents = 125000,
  String currency = 'EGP',
}) => <String, dynamic>{
  'payment_id': paymentId,
  'status': status,
  'checkout_url': checkoutUrl,
  'amount_cents': amountCents,
  'currency': currency,
};

void main() {
  late _StubPaymentApi api;
  late SupabasePaymentGateway gateway;

  setUp(() {
    api = _StubPaymentApi();
    gateway = SupabasePaymentGateway(api);
  });

  group('SupabasePaymentGateway', () {
    test('is live and never offers demo simulation', () {
      expect(gateway.isLive, isTrue);
      expect(gateway.supportsDemoSimulation, isFalse);
      expect(
        () => gateway.simulate('invoice-1', PaymentStatus.succeeded),
        throwsUnsupportedError,
      );
    });

    test('maps the initiate payload to a PaymentSession', () async {
      api.initiateResult = _initiatePayload();

      final Result<PaymentSession> result = await gateway.initiate('invoice-1');

      final PaymentSession session = result.valueOrNull!;
      expect(session.paymentId, 'pay-1');
      expect(session.invoiceId, 'invoice-1');
      expect(session.status, PaymentStatus.pending);
      expect(
        session.checkoutUrl,
        'https://accept.paymob.com/unifiedcheckout/?publicKey=pub',
      );
      expect(session.amountCents, 125000);
      expect(session.currency, 'EGP');
    });

    test('rejects a non-https checkout URL', () async {
      api.initiateResult = _initiatePayload(
        checkoutUrl: 'http://accept.paymob.com/checkout',
      );

      final Result<PaymentSession> result = await gateway.initiate('invoice-1');

      expect(result.errorOrNull?.code, 'payment_initiate_failed');
    });

    test('rejects a checkout URL off the Paymob host allowlist', () async {
      api.initiateResult = _initiatePayload(
        checkoutUrl: 'https://evil.example/checkout',
      );

      final Result<PaymentSession> result = await gateway.initiate('invoice-1');

      expect(result.errorOrNull?.code, 'payment_initiate_failed');
    });

    test('accepts a paymob.com subdomain checkout URL', () async {
      api.initiateResult = _initiatePayload(
        checkoutUrl: 'https://eg.checkout.paymob.com/checkout',
      );

      final Result<PaymentSession> result = await gateway.initiate('invoice-1');

      expect(result.isSuccess, isTrue);
    });

    test('a missing required field fails loudly', () async {
      for (final String key in <String>[
        'payment_id',
        'status',
        'amount_cents',
        'currency',
      ]) {
        final Map<String, dynamic> payload = _initiatePayload()..remove(key);
        api.initiateResult = payload;

        final Result<PaymentSession> result = await gateway.initiate(
          'invoice-1',
        );

        expect(result.isSuccess, isFalse, reason: 'missing $key');
        expect(result.errorOrNull?.code, 'payment_initiate_failed');
      }
    });

    test('an unmapped status fails loudly', () async {
      api.initiateResult = _initiatePayload(status: 'overdue');

      final Result<PaymentSession> result = await gateway.initiate('invoice-1');

      expect(result.errorOrNull?.code, 'payment_initiate_failed');
    });

    test('maps a status payload to a snapshot and parses updated_at', () async {
      api.statusResult = <String, dynamic>{
        'payment_id': 'pay-1',
        'status': 'succeeded',
        'updated_at': '2026-10-20T12:00:00.123456+00:00',
      };

      final Result<PaymentStatusSnapshot> result = await gateway.fetchStatus(
        'invoice-1',
      );

      final PaymentStatusSnapshot snapshot = result.valueOrNull!;
      expect(snapshot.paymentId, 'pay-1');
      expect(snapshot.status, PaymentStatus.succeeded);
      expect(
        snapshot.updatedAt!.toUtc(),
        DateTime.parse('2026-10-20T12:00:00.123456+00:00').toUtc(),
      );
    });

    test('null status maps to the none snapshot', () async {
      api.statusResult = null;

      final PaymentStatusSnapshot snapshot = (await gateway.fetchStatus(
        'invoice-1',
      )).valueOrNull!;

      expect(snapshot.status, PaymentStatus.none);
      expect(snapshot.paymentId, isNull);
      expect(snapshot.updatedAt, isNull);
    });

    test('an unmapped status snapshot fails loudly', () async {
      api.statusResult = <String, dynamic>{
        'payment_id': 'pay-1',
        'status': 'overdue',
        'updated_at': '2026-10-20T12:00:00.000Z',
      };

      final Result<PaymentStatusSnapshot> result = await gateway.fetchStatus(
        'invoice-1',
      );

      expect(result.errorOrNull?.code, 'payment_status_failed');
    });

    test('maps initiate failures to the typed payment codes', () async {
      const Map<SupabasePaymentFailureKind, String> expected =
          <SupabasePaymentFailureKind, String>{
            SupabasePaymentFailureKind.denied: 'payment_initiate_denied',
            SupabasePaymentFailureKind.providerUnavailable:
                'payment_initiate_unavailable',
            SupabasePaymentFailureKind.unknown: 'payment_initiate_failed',
          };

      for (final MapEntry<SupabasePaymentFailureKind, String> entry
          in expected.entries) {
        api.initiateError = SupabasePaymentException(
          kind: entry.key,
          message: 'provider detail',
        );

        final AppError error = (await gateway.initiate(
          'invoice-1',
        )).errorOrNull!;

        expect(error.code, entry.value);
        expect(error.technicalMessage, 'provider detail');
      }
    });

    test('maps status failures to the typed payment codes', () async {
      const Map<SupabasePaymentFailureKind, String> expected =
          <SupabasePaymentFailureKind, String>{
            SupabasePaymentFailureKind.denied: 'payment_status_denied',
            SupabasePaymentFailureKind.providerUnavailable:
                'payment_status_unavailable',
            SupabasePaymentFailureKind.unknown: 'payment_status_failed',
          };

      for (final MapEntry<SupabasePaymentFailureKind, String> entry
          in expected.entries) {
        api.statusError = SupabasePaymentException(
          kind: entry.key,
          message: 'provider detail',
        );

        final AppError error = (await gateway.fetchStatus(
          'invoice-1',
        )).errorOrNull!;

        expect(error.code, entry.value);
      }
    });
  });
}
