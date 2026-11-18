import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/billing/domain/billing_gateway.dart';
import 'package:legalhub/features/billing/domain/checkout_launcher.dart';
import 'package:legalhub/features/billing/domain/invoice.dart';
import 'package:legalhub/features/billing/domain/payment_gateway.dart';
import 'package:legalhub/features/billing/domain/payment_mode.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/formatting/date_formatting.dart';
import 'package:legalhub/shared/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'billing_cubit.dart';
import 'billing_state.dart';
import 'invoice_labels.dart';
import 'invoice_pay_action.dart';

part 'invoice_details_surface.dart';

/// Read-only invoice-metadata detail for one invoice.
///
/// **Metadata only** (D-BI1): number, amount/currency, status, matter
/// reference, issued/due dates and the same pay affordance the list row
/// offers for an issued invoice when payments are enabled. No card data,
/// payer identity, or billing address exists on the domain type, so the
/// surface cannot render them. The pay button opens the existing
/// provider-hosted checkout sheet — card data never touches the app.
class InvoiceDetailsScreen extends StatelessWidget {
  const InvoiceDetailsScreen({
    required this.invoiceId,
    this.embedded = false,
    super.key,
  });

  final String invoiceId;

  /// True inside the two-pane detail slot (no Scaffold/AppBar).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // In the two-pane the parent list owns the cubit; sharing it keeps the
    // list and the detail in sync (a payment settled in the pane must clear
    // the list row's Pay action too) and avoids a duplicate read.
    if (embedded) {
      return _InvoiceDetailsSurface(
        invoiceId: invoiceId,
        embedded: true,
        loadOnMount: false,
      );
    }
    return BlocProvider<BillingCubit>(
      create: (BuildContext context) =>
          BillingCubit(serviceLocator<BillingGateway>()),
      child: _InvoiceDetailsSurface(
        invoiceId: invoiceId,
        embedded: false,
        loadOnMount: true,
      ),
    );
  }
}
