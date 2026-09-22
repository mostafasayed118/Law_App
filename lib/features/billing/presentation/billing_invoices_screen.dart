import 'package:flutter/material.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/billing_gateway.dart';
import '../domain/invoice.dart';
import 'billing_cubit.dart';
import 'billing_state.dart';
import 'invoice_labels.dart';

part 'billing_invoice_tile.dart';

/// Standalone billing-invoices list surface (spec §6 row 158
/// `billing_invoices`; billing slice D-BI5).
///
/// The `/invoices` route renders the assignment-scoped invoice-metadata list
/// (the dev fake in env-less runs, the env-gated `SupabaseBillingGateway`
/// with `invoices_select_assigned` server-side). **Metadata only** — rows
/// render the D-BI1 fields (invoice number, amount, currency, status, matter
/// reference, issued/due dates) and nothing else: no body, no payer
/// identity, **no pay affordance and no row tap** (D-11 — no live payment in
/// MVP; the D-BI1 line is structural).
class BillingInvoicesScreen extends StatelessWidget {
  const BillingInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10): the
      // provider, the post-frame first load, the SafeArea + BlocBuilder and
      // the lazy ViewStateList wiring used to be repeated in this file.
      body: CubitListSurface<BillingCubit, BillingState, Invoice>(
        createCubit: () => BillingCubit(serviceLocator<BillingGateway>()),
        project: (BillingState state) => state.invoices,
        load: (BillingCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, Invoice invoice) =>
            _InvoiceTile(invoice: invoice),
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
        localOnlyNote: l10n.invoicesLocalOnlyNote,
      ),
    );
  }
}
