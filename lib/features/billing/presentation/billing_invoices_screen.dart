import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/demo_labels.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/billing_gateway.dart';
import '../domain/checkout_launcher.dart';
import '../domain/invoice.dart';
import '../domain/payment_gateway.dart';
import '../domain/payment_mode.dart';
import 'billing_cubit.dart';
import 'billing_state.dart';
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
/// `PAYMENTS_MODE` is enabled. The rows stay non-tappable and render no
/// card/payer data — the provider-hosted checkout owns all of it.
class BillingInvoicesScreen extends StatelessWidget {
  const BillingInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool localOnly = backendIsLocalOnly;
    final PaymentMode mode = serviceLocator<PaymentMode>();
    final PaymentGateway paymentGateway = serviceLocator<PaymentGateway>();
    final CheckoutLauncher launcher = serviceLocator<CheckoutLauncher>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10): the
      // provider, the post-frame first load, the SafeArea + BlocBuilder and
      // the lazy ViewStateList wiring used to be repeated in this file.
      body: CubitListSurface<BillingCubit, BillingState, Invoice>(
        createCubit: () => BillingCubit(serviceLocator<BillingGateway>()),
        project: (BillingState state) => state.invoices,
        load: (BillingCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, Invoice invoice) => _InvoiceTile(
          invoice: invoice,
          mode: mode,
          paymentGateway: paymentGateway,
          launcher: launcher,
          onSettled: () => context.read<BillingCubit>().load(),
        ),
        empty: (BuildContext context, BillingState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.invoicesEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.invoicesError,
        localOnlyNote: localOnly ? l10n.invoicesLocalOnlyNote : '',
      ),
    );
  }
}
