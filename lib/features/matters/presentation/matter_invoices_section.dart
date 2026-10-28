import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/features/billing/presentation/invoice_labels.dart';
import 'package:legalhub/features/billing/presentation/invoice_pay_action.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'matter_workspace_cubit.dart';
import 'matter_workspace_state.dart';

/// Per-matter Invoices section on the matter details surface (billing slice,
/// D-BI5).
///
/// Consumes the matter-scoped [MatterWorkspaceCubit] (provided by the
/// details screen) instead of a foreign feature's presentation cubit
/// (audit: matters god-feature). The cubit scopes the gateway read to the
/// open matter server-side, so the list here is already the matter's subset;
/// no client-side title filtering runs. Each row renders the invoice number,
/// the amount, and the status plus the shared pay action for `issued`
/// invoices when `PAYMENTS_MODE` is enabled. No card/payer data and no row
/// tap exist — the provider-hosted checkout owns the card surface. An empty
/// per-matter subset renders the localized empty copy.
class MatterInvoicesSection extends StatefulWidget {
  const MatterInvoicesSection({super.key});

  @override
  State<MatterInvoicesSection> createState() => _MatterInvoicesSectionState();
}

class _MatterInvoicesSectionState extends State<MatterInvoicesSection> {
  @override
  void initState() {
    super.initState();
    // Load the matter-scoped invoice list on open. Only this list loads —
    // sibling sections trigger their own.
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
          viewAllCopy: l10n.viewAll,
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
