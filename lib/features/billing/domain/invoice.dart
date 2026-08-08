import 'package:equatable/equatable.dart';

/// Lifecycle of an invoice row (billing slice, D-BI5).
///
/// Exactly the two values the `billing_invoices.status` CHECK admits
/// (`in ('issued','paid')` — D-11's deliberately minimal mapping contract;
/// no tax/lifecycle machinery). A provider-drift status fails mapping loudly
/// (the gateway's malformed-row guard), never surfaces as a silently wrong
/// invoice.
enum InvoiceStatus { issued, paid }

/// An invoice-metadata preview (ninth §14 un-deferral, billing slice D-BI5).
///
/// Carries **non-PII metadata only**: a stable id, a matter reference, a
/// generic invoice number, an amount in cents, a currency, a status, and the
/// issued/due dates. **There is no card data, no payment method, no billing
/// address, no payer identity, and no pay affordance anywhere on the type**
/// (D-11 — the D-BI1 metadata-only line is enforced structurally, so the
/// surface can never render payment data; raw PAN/CVV cannot even exist in
/// the applied table). Invoices come from the fake gateway's fixed synthetic
/// list in env-less runs — synthetic EGP amounts, no real charges, no PII
/// (D-BI4 — the fake is the product posture, not a stopgap).
class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.matterRef,
    required this.invoiceNumber,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.issuedAt,
    required this.dueAt,
  });

  final String id;

  /// The matter this invoice belongs to, rendered as one of the existing
  /// synthetic matter titles (the same shape `Document.matterRef` and
  /// `MessageThread.matterRef` use — D-W2/D-MSG4/D-STR5; D-BI5).
  final String matterRef;

  /// Generic demo invoice number (e.g. `INV-2026-0001`) — never PII by
  /// convention.
  final String invoiceNumber;

  /// The invoice total in the minor unit (the `billing_invoices.amount_cents`
  /// column, CHECK >= 0). Synthetic demo amounts only (D-11).
  final int amountCents;

  /// ISO-4217 currency code (`EGP` in the demo posture).
  final String currency;

  final InvoiceStatus status;

  final DateTime issuedAt;

  final DateTime dueAt;

  @override
  List<Object?> get props => <Object?>[
    id,
    matterRef,
    invoiceNumber,
    amountCents,
    currency,
    status,
    issuedAt,
    dueAt,
  ];
}
