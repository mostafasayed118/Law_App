import '../../../l10n/app_localizations.dart';
import '../domain/invoice.dart';

/// Localized label for an [InvoiceStatus], rendered as the invoice row's
/// secondary-line status label (billing slice, D-BI5 — the
/// `documentTypeLabel` pattern).
String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus status) =>
    switch (status) {
      InvoiceStatus.issued => l10n.invoiceStatusIssued,
      InvoiceStatus.paid => l10n.invoiceStatusPaid,
    };

/// Formats an amount in the minor unit as a plain decimal string with two
/// fraction digits (e.g. `1250.00`). Locale-independent and deterministic —
/// the row prefixes the VO's currency code itself.
String invoiceAmountLabel(int amountCents) =>
    (amountCents / 100).toStringAsFixed(2);
