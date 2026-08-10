import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Locale-aware medium date (yMMMd — e.g. "Aug 10, 2026"), the exact shape
/// the repo's list-row surfaces render (E6 extraction: the 12 inlined
/// `DateFormat.yMMMd(l10n.localeName)` sites now share this one helper).
///
/// Locale resolution is unchanged — [AppLocalizations.localeName] drives
/// the pattern exactly as before; timezone behavior is unchanged too
/// (callers keep any explicit `.toLocal()` at the call site).
String formatMediumDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMd(l10n.localeName).format(date);

/// Locale-aware medium date plus time (yMMMd + jm), the exact shape of the
/// profile session-expiry row — the one surface that adds the time. Kept as
/// a separate helper so that surface's displayed copy stays byte-identical
/// to the pre-extraction `DateFormat.yMMMd(locale).add_jm()`.
String formatMediumDateTime(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMd(l10n.localeName).add_jm().format(date);
