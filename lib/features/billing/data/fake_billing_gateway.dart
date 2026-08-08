import '../../../core/errors/result.dart';
import '../domain/billing_gateway.dart';
import '../domain/invoice.dart';

/// Development-only billing implementation: a fixed synthetic list of
/// non-PII invoice **metadata**.
///
/// D-BI4 — the fake is the **product posture**, not a stopgap: D-11 says no
/// live payment in MVP, so [fetchInvoices] returns the same deterministic
/// list on every call, with **synthetic demo amounts only** (no real charges)
/// and generic numbers/copy that never read as a real client's invoice (R1).
/// Rows carry id / matter reference (one of the known synthetic matter
/// titles, D-W2) / generic invoice number / amount in cents / currency /
/// status / issued+due dates only — **no card data, no payment method, no
/// payer identity of any kind** (the D-BI1 metadata-only line). The list
/// resolves immediately (no artificial delay) so cubit/widget tests stay
/// timing-independent.
class FakeBillingGateway implements BillingGateway {
  /// The fixed synthetic invoice-metadata list served by [fetchInvoices].
  static final List<Invoice> syntheticInvoices = <Invoice>[
    Invoice(
      id: 'invoice-1',
      matterRef: 'Demo acquisition review',
      invoiceNumber: 'INV-2026-0001',
      amountCents: 125000,
      currency: 'EGP',
      status: InvoiceStatus.issued,
      issuedAt: DateTime(2026, 7, 1),
      dueAt: DateTime(2026, 7, 31),
    ),
    Invoice(
      id: 'invoice-2',
      matterRef: 'Commercial lease consultation',
      invoiceNumber: 'INV-2026-0002',
      amountCents: 87500,
      currency: 'EGP',
      status: InvoiceStatus.paid,
      issuedAt: DateTime(2026, 6, 15),
      dueAt: DateTime(2026, 7, 15),
    ),
    Invoice(
      id: 'invoice-3',
      matterRef: 'Procedural review matter',
      invoiceNumber: 'INV-2026-0003',
      amountCents: 62000,
      currency: 'EGP',
      status: InvoiceStatus.issued,
      issuedAt: DateTime(2026, 7, 10),
      dueAt: DateTime(2026, 8, 9),
    ),
    Invoice(
      id: 'invoice-4',
      matterRef: 'Family status consultation',
      invoiceNumber: 'INV-2026-0004',
      amountCents: 45000,
      currency: 'EGP',
      status: InvoiceStatus.paid,
      issuedAt: DateTime(2026, 5, 20),
      dueAt: DateTime(2026, 6, 19),
    ),
    Invoice(
      id: 'invoice-5',
      matterRef: 'Startup formation advisory',
      invoiceNumber: 'INV-2026-0005',
      amountCents: 98000,
      currency: 'EGP',
      status: InvoiceStatus.issued,
      issuedAt: DateTime(2026, 7, 20),
      dueAt: DateTime(2026, 8, 19),
    ),
  ];

  @override
  Future<Result<List<Invoice>>> fetchInvoices() async {
    // Metadata only — the synthetic list is returned as-is; nothing crosses
    // this boundary but the D-BI1 metadata surface (no payment capability).
    return Result<List<Invoice>>.success(syntheticInvoices);
  }
}
