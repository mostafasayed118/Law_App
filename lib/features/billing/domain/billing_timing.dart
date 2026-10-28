/// Cadence of live invoice-payment status polling.
const Duration kPaymentPollInterval = Duration(seconds: 5);

/// Maximum time live invoice-payment status polling remains active.
const Duration kPaymentPollTimeout = Duration(minutes: 2);
