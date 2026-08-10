import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).invoicesTitle)),
      body: BlocProvider<BillingCubit>(
        create: (BuildContext context) =>
            BillingCubit(serviceLocator<BillingGateway>()),
        child: const _InvoicesSurface(),
      ),
    );
  }
}

class _InvoicesSurface extends StatefulWidget {
  const _InvoicesSurface();

  @override
  State<_InvoicesSurface> createState() => _InvoicesSurfaceState();
}

class _InvoicesSurfaceState extends State<_InvoicesSurface> {
  @override
  void initState() {
    super.initState();
    // The cubit's initial state is already loading, so the first frame
    // settles straight into the fake's immediate list (the vault/messages
    // pattern).
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
    final Widget empty = Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
      child: Text(
        l10n.invoicesEmpty,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return SafeArea(
      child: BlocBuilder<BillingCubit, BillingState>(
        builder: (BuildContext context, BillingState state) {
          return ViewStateSwitch<List<Invoice>>(
            state: state.invoices,
            onRetry: () => context.read<BillingCubit>().load(),
            builder: (BuildContext context, List<Invoice> invoices) => ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                for (final Invoice invoice in invoices) ...<Widget>[
                  _InvoiceTile(invoice: invoice),
                  const SizedBox(height: LegalHubTheme.spaceSm),
                ],
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.invoicesLocalOnlyNote,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            empty: empty,
            errorCopy: l10n.invoicesError,
          );
        },
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
