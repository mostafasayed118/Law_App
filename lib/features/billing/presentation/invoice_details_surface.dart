part of 'invoice_details_screen.dart';

class _InvoiceDetailsSurface extends StatefulWidget {
  const _InvoiceDetailsSurface({
    required this.invoiceId,
    required this.embedded,
    required this.loadOnMount,
  });

  final String invoiceId;
  final bool embedded;

  /// Standalone details load the list themselves; the two-pane reads the
  /// parent list's already-loaded cubit.
  final bool loadOnMount;

  @override
  State<_InvoiceDetailsSurface> createState() => _InvoiceDetailsSurfaceState();
}

class _InvoiceDetailsSurfaceState extends State<_InvoiceDetailsSurface> {
  @override
  void initState() {
    super.initState();
    if (!widget.loadOnMount) {
      return;
    }
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
    final Widget body = SafeArea(
      child: BlocBuilder<BillingCubit, BillingState>(
        builder: (BuildContext context, BillingState state) {
          return switch (state.invoices) {
            ViewLoading() => const Center(child: CircularProgressIndicator()),
            ViewEmpty() => AppCenteredMessage(
              text: l10n.invoiceDetailsNotFound,
            ),
            ViewError() => AppCenteredRetry(
              message: l10n.invoicesError,
              onRetry: context.read<BillingCubit>().load,
              retryLabel: l10n.retry,
            ),
            ViewOffline() || ViewUnauthorized() => AppCenteredMessage(
              text: l10n.invoiceDetailsNotFound,
            ),
            ViewSuccess(data: final List<Invoice> invoices) => _details(
              context,
              l10n,
              _findById(invoices, widget.invoiceId),
            ),
          };
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoiceDetailsTitle)),
      body: body,
    );
  }

  Invoice? _findById(List<Invoice> invoices, String id) {
    for (final Invoice invoice in invoices) {
      if (invoice.id == id) {
        return invoice;
      }
    }
    return null;
  }

  Widget _details(
    BuildContext context,
    AppLocalizations l10n,
    Invoice? invoice,
  ) {
    if (invoice == null) {
      return AppCenteredMessage(text: l10n.invoiceDetailsNotFound);
    }
    final DemoLabels labels = DemoLabels(l10n, localOnly: backendIsLocalOnly);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final PaymentMode mode = serviceLocator<PaymentMode>();
    final PaymentGateway paymentGateway = serviceLocator<PaymentGateway>();
    final CheckoutLauncher launcher = serviceLocator<CheckoutLauncher>();
    final bool paid = invoice.status == InvoiceStatus.paid;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Text(invoice.invoiceNumber, style: text.headlineSmall),
        const SizedBox(height: LegalHubTheme.spaceMd),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LabelChip(
            label: invoiceStatusLabel(l10n, invoice.status),
            background: paid
                ? scheme.secondaryContainer
                : scheme.tertiaryContainer,
            foreground: paid
                ? scheme.onSecondaryContainer
                : scheme.onTertiaryContainer,
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        _MetaRow(
          label: l10n.invoiceDetailsAmount,
          value:
              '${invoice.currency} ${invoiceAmountLabel(invoice.amountCents)}',
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _MetaRow(
          label: l10n.invoiceDetailsMatter,
          value: labels.matterTitle(invoice.matterRef),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _MetaRow(
          label: l10n.invoiceDetailsIssued,
          value: formatMediumDate(l10n, invoice.issuedAt),
        ),
        const SizedBox(height: LegalHubTheme.spaceMd),
        _MetaRow(
          label: l10n.invoiceDetailsDue,
          value: formatMediumDate(l10n, invoice.dueAt),
        ),
        if (!paid && mode != PaymentMode.disabled) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceLg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InvoicePayAction(
              invoice: invoice,
              mode: mode,
              gateway: paymentGateway,
              launcher: launcher,
              onSettled: () => context.read<BillingCubit>().load(),
            ),
          ),
        ],
        const SizedBox(height: LegalHubTheme.spaceXl),
        if (backendIsLocalOnly)
          Text(
            l10n.invoicesLocalOnlyNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// One label/value metadata row.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.space2xs),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}
