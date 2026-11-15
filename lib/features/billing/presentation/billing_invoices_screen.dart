import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/responsive/breakpoints.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'billing_cubit.dart';
import 'billing_state.dart';
import 'invoice_details_screen.dart';
import 'invoice_labels.dart';
import 'invoice_pay_action.dart';

part 'billing_invoice_tile.dart';

/// Standalone billing-invoices list surface (spec §6 row 158
/// `billing_invoices`; billing slice D-BI5).
///
/// The `/invoices` route renders the assignment-scoped invoice-metadata list
/// (the dev fake in env-less runs, the env-gated `SupabaseBillingGateway`
/// with `invoices_select_assigned` server-side). Rows render the D-BI1
/// fields (invoice number, amount, currency, status, matter reference,
/// issued/due dates) plus the shared pay action for `issued` invoices when
/// `PAYMENTS_MODE` is enabled. The row opens the metadata detail
/// (`/invoices/:id`); that detail shows the same metadata and the same pay
/// action. No card/payer data ever exists on the client type.
///
/// On expanded windows (≥840dp) the screen is a two-pane master/detail: the
/// invoice list stays on the left and the selected invoice renders on the
/// right. Compact/medium windows keep push navigation.
class BillingInvoicesScreen extends StatefulWidget {
  const BillingInvoicesScreen({this.initialSelectedInvoiceId, super.key});

  /// Deep-link projection: `/invoices/:id` on an expanded window opens the
  /// two-pane with this invoice selected.
  final String? initialSelectedInvoiceId;

  @override
  State<BillingInvoicesScreen> createState() => _BillingInvoicesScreenState();
}

class _BillingInvoicesScreenState extends State<BillingInvoicesScreen> {
  String? _selectedInvoiceId;

  @override
  void initState() {
    super.initState();
    _selectedInvoiceId = widget.initialSelectedInvoiceId;
  }

  @override
  void didUpdateWidget(BillingInvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedInvoiceId != oldWidget.initialSelectedInvoiceId) {
      _selectedInvoiceId = widget.initialSelectedInvoiceId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool localOnly = backendIsLocalOnly;
    final PaymentMode mode = serviceLocator<PaymentMode>();
    final PaymentGateway paymentGateway = serviceLocator<PaymentGateway>();
    final CheckoutLauncher launcher = serviceLocator<CheckoutLauncher>();
    final bool twoPane =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return BlocProvider<BillingCubit>(
      create: (BuildContext context) =>
          BillingCubit(serviceLocator<BillingGateway>()),
      child: twoPane
          ? _buildTwoPane(
              l10n,
              mode: mode,
              paymentGateway: paymentGateway,
              launcher: launcher,
              localOnly: localOnly,
            )
          : _ListSurface(
              mode: mode,
              paymentGateway: paymentGateway,
              launcher: launcher,
              localOnly: localOnly,
            ),
    );
  }

  Widget _buildTwoPane(
    AppLocalizations l10n, {
    required PaymentMode mode,
    required PaymentGateway paymentGateway,
    required CheckoutLauncher launcher,
    required bool localOnly,
  }) {
    final String? selectedId = _selectedInvoiceId;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      body: SafeArea(
        child: TwoPane(
          list: _ListSurface(
            embedded: true,
            mode: mode,
            paymentGateway: paymentGateway,
            launcher: launcher,
            localOnly: localOnly,
            selectedInvoiceId: selectedId,
            onSelectInvoice: (String id) =>
                setState(() => _selectedInvoiceId = id),
          ),
          detail: selectedId == null
              ? AppCenteredMessage(text: l10n.invoiceDetailsTitle)
              : InvoiceDetailsScreen(
                  key: ValueKey<String>(selectedId),
                  invoiceId: selectedId,
                  embedded: true,
                ),
        ),
      ),
    );
  }
}

class _ListSurface extends StatefulWidget {
  const _ListSurface({
    required this.mode,
    required this.paymentGateway,
    required this.launcher,
    required this.localOnly,
    this.embedded = false,
    this.selectedInvoiceId,
    this.onSelectInvoice,
  });

  final PaymentMode mode;
  final PaymentGateway paymentGateway;
  final CheckoutLauncher launcher;
  final bool localOnly;

  /// True inside the two-pane: the pane owns no Scaffold/AppBar.
  final bool embedded;

  /// The invoice rendered by the detail pane (two-pane only).
  final String? selectedInvoiceId;

  /// Selection callback for two-pane. Null restores push navigation.
  final ValueChanged<String>? onSelectInvoice;

  @override
  State<_ListSurface> createState() => _ListSurfaceState();
}

class _ListSurfaceState extends State<_ListSurface> {
  bool _autoSelected = false;

  @override
  void initState() {
    super.initState();
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget body = SafeArea(
      child: BlocBuilder<BillingCubit, BillingState>(
        builder: (BuildContext context, BillingState state) {
          _maybeAutoSelect(state);
          return _resultsView(context, state, l10n, text, scheme);
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      body: body,
    );
  }

  /// Auto-selects the first loaded invoice once per list mount.
  void _maybeAutoSelect(BillingState state) {
    if (_autoSelected ||
        widget.onSelectInvoice == null ||
        widget.selectedInvoiceId != null) {
      return;
    }
    if (state.invoices case ViewSuccess<List<Invoice>>(
      data: final List<Invoice> invoices,
    ) when invoices.isNotEmpty) {
      _autoSelected = true;
      final String firstId = invoices.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSelectInvoice!(firstId);
        }
      });
    }
  }

  /// Opens the metadata detail and re-reads the list on return so a payment
  /// settled in the detail clears the row's pay action (the detail owns its
  /// own cubit on the phone path).
  Future<void> _openInvoice(String invoiceId) async {
    await context.push(AppRoutes.invoiceDetail(invoiceId));
    if (!mounted) {
      return;
    }
    await context.read<BillingCubit>().load();
  }

  Widget _resultsView(
    BuildContext context,
    BillingState state,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final BillingCubit cubit = context.read<BillingCubit>();
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.invoicesEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return ViewStateList<Invoice>(
      state: state.invoices,
      onRetry: cubit.load,
      tileBuilder: (BuildContext context, Invoice invoice) => _InvoiceTile(
        invoice: invoice,
        mode: widget.mode,
        paymentGateway: widget.paymentGateway,
        launcher: widget.launcher,
        localOnly: widget.localOnly,
        onSettled: cubit.load,
        // Two-pane: select in place. Compact/medium: forward navigation to
        // the metadata detail.
        onOpen: widget.onSelectInvoice == null
            ? () => _openInvoice(invoice.id)
            : () => widget.onSelectInvoice!(invoice.id),
      ),
      empty: empty,
      errorCopy: l10n.invoicesError,
      localOnlyNote: widget.localOnly ? l10n.invoicesLocalOnlyNote : '',
      listPadding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    );
  }
}
