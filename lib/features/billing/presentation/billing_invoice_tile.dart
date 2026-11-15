part of 'billing_invoices_screen.dart';

/// An invoice-metadata row. The row opens the metadata detail; the only
/// nested action is the [InvoicePayAction] for an `issued` invoice when
/// payments are enabled.
class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.mode,
    required this.paymentGateway,
    required this.launcher,
    required this.localOnly,
    required this.onSettled,
    required this.onOpen,
  });

  final Invoice invoice;
  final PaymentMode mode;
  final PaymentGateway paymentGateway;
  final CheckoutLauncher launcher;
  final bool localOnly;
  final Future<void> Function() onSettled;

  /// Whole-row open → the metadata detail.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DemoLabels labels = DemoLabels(l10n, localOnly: localOnly);
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
        '${labels.matterTitle(invoice.matterRef)} · $issued',
      ],
      onTap: onOpen,
      trailing: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: InvoicePayAction(
          invoice: invoice,
          mode: mode,
          gateway: paymentGateway,
          launcher: launcher,
          onSettled: onSettled,
        ),
      ),
    );
  }
}
