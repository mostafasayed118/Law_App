import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_entry_card.dart';

/// Home-dashboard entry into the standalone billing-invoices surface
/// (`/invoices`, spec §6 row 158; billing slice D-BI5).
///
/// Rendered on the home screen when the session's role grants
/// [RoleCapability] — **reusing `canViewDocuments`** per the D-BI5 decision
/// ("no new capability flag": invoices are matter-scoped content with the
/// same client/attorney SHIP cells as documents, so the standalone surface
/// rides the same nav hint; see the same rationale in
/// `matter_details_screen.dart`). Like every capability flag in this product,
/// it is a navigation hint only — never an authorization grant.
///
/// E1 compatibility wrapper: the visual shell is the shared [AppEntryCard];
/// this class keeps the feature's icon + localized copy and the public name
/// the home screen and tests construct by type.
class BillingInvoicesEntryCard extends StatelessWidget {
  const BillingInvoicesEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppEntryCard(
      icon: Icons.request_quote_outlined,
      title: l10n.invoicesEntryTitle,
      subtitle: l10n.invoicesEntrySubtitle,
      onTap: onTap,
    );
  }
}
