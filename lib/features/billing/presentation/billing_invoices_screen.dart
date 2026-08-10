import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
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
          return switch (state.invoices) {
            ViewLoading() => const Padding(
              padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
              child: Center(child: CircularProgressIndicator()),
            ),
            ViewEmpty() => empty,
            ViewError() => Padding(
              padding: const EdgeInsetsDirectional.only(
                top: LegalHubTheme.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.invoicesError,
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                  TextButton(
                    onPressed: () => context.read<BillingCubit>().load(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            // The sealed ViewState set also carries offline/unauthorized
            // variants; the synthetic list has neither state, so both render
            // the same empty copy (the vault/messages posture).
            ViewOffline() || ViewUnauthorized() => empty,
            ViewSuccess<List<Invoice>>(data: final List<Invoice> invoices) =>
              ListView(
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
          };
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String amount = invoiceAmountLabel(invoice.amountCents);
    final String status = invoiceStatusLabel(l10n, invoice.status);
    final String issued = formatMediumDate(l10n, invoice.issuedAt);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.request_quote_outlined,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    invoice.invoiceNumber,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.currency} $amount · $status',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.matterRef} · $issued',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LegalHubTheme.spaceSm),
          ],
        ),
      ),
    );
  }
}
