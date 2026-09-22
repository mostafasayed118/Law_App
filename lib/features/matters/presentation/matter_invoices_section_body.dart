part of 'matter_invoices_section.dart';

class _InvoicesSectionBody extends StatefulWidget {
  const _InvoicesSectionBody({required this.matterRef});

  final String matterRef;

  @override
  State<_InvoicesSectionBody> createState() => _InvoicesSectionBodyState();
}

class _InvoicesSectionBodyState extends State<_InvoicesSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load the list on open (same pattern as the standalone surfaces); the
    // per-matter subset is filtered client-side below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<BillingCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (BuildContext context, BillingState state) {
        return WorkspaceSection<Invoice>(
          state: state.invoices,
          onRetry: () => context.read<BillingCubit>().load(),
          errorCopy: l10n.invoicesError,
          emptyCopy: l10n.matterWorkspaceInvoicesEmpty,
          matterRef: widget.matterRef,
          matterRefOf: (Invoice invoice) => invoice.matterRef,
          itemBuilder: (BuildContext context, Invoice invoice) => AppTile(
            title: invoice.invoiceNumber,
            subtitles: <String>[
              '${invoice.currency} '
                  '${invoiceAmountLabel(invoice.amountCents)} · '
                  '${invoiceStatusLabel(l10n, invoice.status)}',
            ],
          ),
        );
      },
    );
  }
}
