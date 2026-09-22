part of 'billing_invoices_screen.dart';

/// A read-only invoice-metadata row. Carries **no onTap, no TapTarget, and
/// no trailing action** — the D-BI1 metadata-only line: rows must not read as
/// tappable and no pay affordance exists (D-11).
class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String amount = invoiceAmountLabel(invoice.amountCents);
    final String status = invoiceStatusLabel(l10n, invoice.status);
    final String issued = formatMediumDate(l10n, invoice.issuedAt);
    // Two metadata lines via AppTile's multi-line subtitles; the stray
    // trailing gap of the pre-E2 row was dropped (owner-ratified cleanup,
    // docs/invoice_tile_followup_design_2026-08-11.md §4).
    return AppTile(
      icon: Icons.request_quote_outlined,
      title: invoice.invoiceNumber,
      subtitles: <String>[
        '${invoice.currency} $amount · $status',
        '${invoice.matterRef} · $issued',
      ],
    );
  }
}
