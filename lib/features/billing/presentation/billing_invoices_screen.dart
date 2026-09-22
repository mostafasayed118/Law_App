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
