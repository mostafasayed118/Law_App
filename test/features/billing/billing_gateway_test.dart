import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/billing/data/fake_billing_gateway.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';

void main() {
  group('FakeBillingGateway.fetchInvoices (D-BI5)', () {
    test('returns the fixed synthetic list, deterministic per call', () async {
      final FakeBillingGateway gateway = FakeBillingGateway();

      final List<Invoice>? first = (await gateway.fetchInvoices()).valueOrNull;
      final List<Invoice>? second = (await gateway.fetchInvoices()).valueOrNull;

      // Same values on every call — no wall-clock or random dependence.
      expect(first, FakeBillingGateway.syntheticInvoices);
      expect(second, first);
      expect(first, hasLength(5));
    });

    test('invoices carry only non-PII metadata fields (D-BI1 shape)', () async {
      final FakeBillingGateway gateway = FakeBillingGateway();

      final List<Invoice> invoices =
          (await gateway.fetchInvoices()).valueOrNull!;

      // Every synthetic invoice exposes the D-BI5 surface: id / matter
      // reference / generic invoice number / amount in cents / currency /
      // status / issued+due dates. Metadata only — the string forms must
      // never render payment or client-identity shapes (no card, no PAN, no
      // email/phone/address).
      for (final Invoice invoice in invoices) {
        expect(invoice.id, isNotEmpty);
        expect(invoice.matterRef, isNotEmpty);
        expect(invoice.invoiceNumber, startsWith('INV-'));
        expect(invoice.amountCents, greaterThanOrEqualTo(0));
        expect(invoice.currency, isNotEmpty);
        expect(invoice.status, isA<InvoiceStatus>());
        expect(invoice.toString(), isNot(contains('@')));
      }
    });

    test('every invoice references a known synthetic matter title (D-BI5)', () {
      final List<Invoice> invoices = FakeBillingGateway.syntheticInvoices;

      // D-BI5 pin (the D-W2 discipline extended to invoices): each invoice's
      // matterRef is one of the known synthetic matter titles (the same set
      // Document.matterRef / MessageThread.matterRef use) — the per-matter
      // association must never read as a real case reference.
      const Set<String> knownMatterTitles = <String>{
        'Demo acquisition review',
        'Commercial lease consultation',
        'Procedural review matter',
        'Family status consultation',
        'Startup formation advisory',
      };
      for (final Invoice invoice in invoices) {
        expect(
          knownMatterTitles,
          contains(invoice.matterRef),
          reason: 'invoice ${invoice.id} references an unknown matter',
        );
      }
      // Every known matter has at least one synthetic invoice, so the
      // per-matter workspace view never dead-ends into an always-empty
      // section for a matter that exists in the demo roster.
      for (final String title in knownMatterTitles) {
        expect(
          invoices.where((Invoice i) => i.matterRef == title),
          isNotEmpty,
          reason: 'no synthetic invoice for $title',
        );
      }
    });

    test('statuses stay within the D-11 minimal CHECK set', () {
      final List<Invoice> invoices = FakeBillingGateway.syntheticInvoices;

      // issued/paid only — the exact set the billing_invoices.status CHECK
      // admits (D-11: no tax/lifecycle machinery).
      for (final Invoice invoice in invoices) {
        expect(const <InvoiceStatus>{
          InvoiceStatus.issued,
          InvoiceStatus.paid,
        }, contains(invoice.status));
      }
    });

    test('no payment surface: the VO exposes no card or charge field', () {
      final List<Invoice> invoices = FakeBillingGateway.syntheticInvoices;

      // D-11: no live payment in MVP — the metadata-only line is structural.
      // Amounts are synthetic demo values (no real charges), and no string
      // form carries a card/payment shape.
      for (final Invoice invoice in invoices) {
        expect(invoice.toString(), isNot(contains('card')));
        expect(invoice.toString(), isNot(contains('pay')));
      }
    });
  });
}
