import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../billing/domain/checkout_launcher.dart';
import '../../billing/domain/invoice.dart';
import '../../billing/domain/payment_gateway.dart';
import '../../billing/domain/payment_mode.dart';
import '../../billing/presentation/invoice_labels.dart';
import '../../billing/presentation/invoice_pay_action.dart';
import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Invoices section on the matter details surface (billing slice,
/// D-BI5).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature) and renders the subset of the
/// invoice-metadata list whose [Invoice.matterRef] equals [matterRef] — a
/// client-side view over the gateway list (the D-M5 pattern; there is no
/// per-matter fetch). Each row renders the invoice number, the amount, and
/// the status plus the shared pay action for `issued` invoices when
/// `PAYMENTS_MODE` is enabled. No card/payer data and no row tap exist —
/// the provider-hosted checkout owns the card surface. An empty per-matter
/// subset renders the localized empty copy.
class MatterInvoicesSection extends StatefulWidget {
  const MatterInvoicesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [Invoice.matterRef], D-BI5).
  final String matterRef;

  @override
  State<MatterInvoicesSection> createState() => _MatterInvoicesSectionState();
}

class _MatterInvoicesSectionState extends State<MatterInvoicesSection> {
  @override
  void initState() {
    super.initState();
    // Load the list on open (same pattern as the standalone surfaces); the
    // per-matter subset is filtered client-side below. Only this list
    // loads — sibling sections trigger their own.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MatterWorkspaceCubit>().loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PaymentMode mode = serviceLocator<PaymentMode>();
    final PaymentGateway paymentGateway = serviceLocator<PaymentGateway>();
    final CheckoutLauncher launcher = serviceLocator<CheckoutLauncher>();
    return BlocBuilder<MatterWorkspaceCubit, MatterWorkspaceState>(
      buildWhen:
          (MatterWorkspaceState previous, MatterWorkspaceState current) =>
              previous.invoices != current.invoices,
      builder: (BuildContext context, MatterWorkspaceState state) {
        return WorkspaceSection<Invoice>(
          state: state.invoices,
          onRetry: () => context.read<MatterWorkspaceCubit>().loadInvoices(),
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
            trailing: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: InvoicePayAction(
                invoice: invoice,
                mode: mode,
                gateway: paymentGateway,
                launcher: launcher,
                onSettled: () =>
                    context.read<MatterWorkspaceCubit>().loadInvoices(),
              ),
            ),
          ),
        );
      },
    );
  }
}
