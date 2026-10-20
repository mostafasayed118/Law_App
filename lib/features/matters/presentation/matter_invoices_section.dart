import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../billing/domain/invoice.dart';
import '../../billing/presentation/invoice_labels.dart';
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
/// per-matter fetch). **Metadata only**: each row renders the invoice
/// number, the amount, and the status — no pay action, no payment data, no
/// tap affordance (D-11 — no live payment in MVP; the D-BI1 line is
/// structural). An empty per-matter subset renders the localized empty
/// copy.
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
          ),
        );
      },
    );
  }
}
