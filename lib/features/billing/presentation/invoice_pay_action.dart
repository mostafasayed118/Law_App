import 'package:flutter/material.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/l10n/app_localizations.dart';

import 'invoice_payment_sheet.dart';

/// The single pay affordance shared by the standalone invoice list and the
/// matter invoices section.
///
/// Rendered only for an `issued` invoice when payments are enabled
/// (`PaymentMode != disabled`). The widget owns the duplicate-open guard; the
/// cubit owns the duplicate-attempt guard.
class InvoicePayAction extends StatefulWidget {
  const InvoicePayAction({
    required this.invoice,
    required this.mode,
    required this.gateway,
    required this.launcher,
    required this.onSettled,
    super.key,
  });

  final Invoice invoice;
  final PaymentMode mode;
  final PaymentGateway gateway;
  final CheckoutLauncher launcher;

  /// Called once when the attempt reaches `succeeded`; the owner refreshes its
  /// invoice list.
  final Future<void> Function() onSettled;

  @override
  State<InvoicePayAction> createState() => _InvoicePayActionState();
}

class _InvoicePayActionState extends State<InvoicePayAction> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      await showInvoicePaymentSheet(
        context: context,
        invoice: widget.invoice,
        gateway: widget.gateway,
        launcher: widget.launcher,
        onSettled: widget.onSettled,
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invoice.status != InvoiceStatus.issued ||
        widget.mode == PaymentMode.disabled) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: _open,
      child: Text(AppLocalizations.of(context).invoicePayAction),
    );
  }
}
