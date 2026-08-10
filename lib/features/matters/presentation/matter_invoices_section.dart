import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../features/billing/domain/billing_gateway.dart';
import '../../../features/billing/domain/invoice.dart';
import '../../../features/billing/presentation/billing_cubit.dart';
import '../../../features/billing/presentation/billing_state.dart';
import '../../../features/billing/presentation/invoice_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// Per-matter Invoices section on the matter details surface (billing slice,
/// D-BI5).
///
/// Provides its own [BillingCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the invoice-metadata list whose
/// [Invoice.matterRef] equals [matterRef] — a client-side view over the
/// gateway list (the D-M5 pattern; there is no per-matter fetch). **Metadata
/// only**: each row renders the invoice number, the amount, and the status —
/// no pay action, no payment data, no tap affordance (D-11 — no live payment
/// in MVP; the D-BI1 line is structural). An empty per-matter subset renders
/// the localized empty copy.
class MatterInvoicesSection extends StatelessWidget {
  const MatterInvoicesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [Invoice.matterRef], D-BI5).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BillingCubit>(
      create: (BuildContext context) =>
          BillingCubit(serviceLocator<BillingGateway>()),
      child: _InvoicesSectionBody(matterRef: matterRef),
    );
  }
}

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (BuildContext context, BillingState state) {
        return ViewStateSwitch<List<Invoice>>(
          state: state.invoices,
          onRetry: () => context.read<BillingCubit>().load(),
          builder: (BuildContext context, List<Invoice> invoices) =>
              _rows(context, invoices, l10n, text, scheme),
          empty: _empty(l10n, text, scheme),
          errorCopy: l10n.invoicesError,
          loadingPadding: const EdgeInsetsDirectional.all(
            LegalHubTheme.spaceMd,
          ),
          errorPadding: EdgeInsets.zero,
          errorTextStyle: text.bodySmall?.copyWith(color: scheme.error),
        );
      },
    );
  }

  Widget _rows(
    BuildContext context,
    List<Invoice> invoices,
    AppLocalizations l10n,
    TextTheme text,
    ColorScheme scheme,
  ) {
    final List<Invoice> matched = invoices
        .where((Invoice i) => i.matterRef == widget.matterRef)
        .toList();
    if (matched.isEmpty) {
      return _empty(l10n, text, scheme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Invoice invoice in matched) ...<Widget>[
          AppTile(
            title: invoice.invoiceNumber,
            subtitles: <String>[
              '${invoice.currency} '
                  '${invoiceAmountLabel(invoice.amountCents)} · '
                  '${invoiceStatusLabel(l10n, invoice.status)}',
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceSm),
        ],
      ],
    );
  }

  Widget _empty(AppLocalizations l10n, TextTheme text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceXs),
      child: Text(
        l10n.matterWorkspaceInvoicesEmpty,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
