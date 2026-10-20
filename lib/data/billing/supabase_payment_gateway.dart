import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/billing/domain/payment_gateway.dart';
import '../../features/billing/domain/payment_session.dart';
import '../../features/billing/domain/payment_status.dart';
import 'supabase_payment_api.dart';

/// [PaymentGateway] backed by the payments slice's server contract.
///
/// Mapping is strict: every required field is validated and any provider
/// drift throws a [FormatException] that becomes a typed failure, never a
/// silently wrong payment. Checkout URLs must be `https` and on a Paymob host
/// (or a `.paymob.com` subdomain); any other scheme/host is refused before the
/// launcher ever sees it.
class SupabasePaymentGateway extends PaymentGateway {
  SupabasePaymentGateway(this._api);

  final SupabasePaymentApi _api;

  @override
  bool get isLive => true;

  @override
  bool get supportsDemoSimulation => false;

  @override
  Future<Result<PaymentSession>> initiate(String invoiceId) async {
    try {
      final Map<String, dynamic> data = await _api.initiate(invoiceId);
      return Result<PaymentSession>.success(_sessionFrom(data, invoiceId));
    } on SupabasePaymentException catch (e) {
      return Result<PaymentSession>.failure(_failure(e, 'initiate'));
    } on FormatException catch (e) {
      return Result<PaymentSession>.failure(
        AppError(
          code: 'payment_initiate_failed',
          userMessage: 'Unable to start the payment. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  @override
  Future<Result<PaymentStatusSnapshot>> fetchStatus(String invoiceId) async {
    try {
      final Map<String, dynamic>? data = await _api.fetchStatus(invoiceId);
      if (data == null) {
        return const Result<PaymentStatusSnapshot>.success(
          PaymentStatusSnapshot.none(),
        );
      }
      return Result<PaymentStatusSnapshot>.success(_snapshotFrom(data));
    } on SupabasePaymentException catch (e) {
      return Result<PaymentStatusSnapshot>.failure(_failure(e, 'status'));
    } on FormatException catch (e) {
      return Result<PaymentStatusSnapshot>.failure(
        AppError(
          code: 'payment_status_failed',
          userMessage: 'Unable to check the payment status. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  PaymentSession _sessionFrom(Map<String, dynamic> data, String invoiceId) {
    final String paymentId = _requiredString(data, 'payment_id');
    final String status = _requiredString(data, 'status');
    final int amountCents = _requiredInt(data, 'amount_cents');
    final String currency = _requiredString(data, 'currency');
    return PaymentSession(
      paymentId: paymentId,
      invoiceId: invoiceId,
      status: PaymentStatus.fromWire(status),
      checkoutUrl: _checkoutUrl(data['checkout_url']),
      amountCents: amountCents,
      currency: currency,
    );
  }

  PaymentStatusSnapshot _snapshotFrom(Map<String, dynamic> data) {
    final Object? updatedAt = data['updated_at'];
    return PaymentStatusSnapshot(
      paymentId: _requiredString(data, 'payment_id'),
      status: PaymentStatus.fromWire(_requiredString(data, 'status')),
      updatedAt: _dateTime(updatedAt),
    );
  }

  String _requiredString(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Payment response has no $key');
    }
    return value;
  }

  int _requiredInt(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is! int || value < 0) {
      throw FormatException('Payment response has an invalid $key');
    }
    return value;
  }

  DateTime _dateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw const FormatException('Payment response has an invalid updated_at');
  }

  /// Accepts only an `https` URL on the Paymob checkout host allowlist.
  String? _checkoutUrl(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String || value.isEmpty) {
      throw const FormatException(
        'Payment response has an invalid checkout_url',
      );
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException(
        'Payment response has an invalid checkout_url',
      );
    }
    if (!_isAllowedCheckoutHost(uri.host.toLowerCase())) {
      throw const FormatException(
        'Payment response has an untrusted checkout host',
      );
    }
    return value;
  }

  bool _isAllowedCheckoutHost(String host) =>
      host == 'paymob.com' ||
      host == 'accept.paymob.com' ||
      host.endsWith('.paymob.com');

  AppError _failure(SupabasePaymentException e, String operation) {
    final bool initiate = operation == 'initiate';
    final (
      String code,
      String userMessage,
      AppErrorKind kind,
    ) = switch (e.kind) {
      SupabasePaymentFailureKind.denied => (
        'payment_${operation}_denied',
        initiate
            ? 'You do not have permission to pay this invoice.'
            : 'You do not have permission to view this payment.',
        AppErrorKind.denied,
      ),
      SupabasePaymentFailureKind.providerUnavailable => (
        'payment_${operation}_unavailable',
        initiate
            ? 'Payments are temporarily unavailable. Please try again.'
            : 'Payment status is temporarily unavailable. Please try again.',
        AppErrorKind.unavailable,
      ),
      SupabasePaymentFailureKind.unknown => (
        'payment_${operation}_failed',
        initiate
            ? 'Unable to start the payment. Please try again.'
            : 'Unable to check the payment status. Please try again.',
        AppErrorKind.unknown,
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      kind: kind,
      technicalMessage: e.message,
    );
  }
}
