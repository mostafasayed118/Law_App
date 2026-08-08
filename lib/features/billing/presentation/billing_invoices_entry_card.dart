import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';

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
class BillingInvoicesEntryCard extends StatelessWidget {
  const BillingInvoicesEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.request_quote_outlined,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                  fill: 1,
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.invoicesEntryTitle,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.invoicesEntrySubtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
