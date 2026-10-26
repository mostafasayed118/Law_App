import 'package:intl/intl.dart';

import 'package:legalhub/l10n/app_localizations.dart';

/// Locale-aware medium date (yMMMd — e.g. "Aug 10, 2026"), the exact shape
/// the repo's list-row surfaces render (E6 extraction: the 12 inlined
/// `DateFormat.yMMMd(l10n.localeName)` sites now share this one helper).
///
/// Locale resolution is unchanged — [AppLocalizations.localeName] drives
/// the pattern exactly as before; timezone behavior is unchanged too
/// (callers keep any explicit `.toLocal()` at the call site).
final Map<String, DateFormat> _mediumDateCache = <String, DateFormat>{};
final Map<String, DateFormat> _mediumDateTimeCache = <String, DateFormat>{};

String formatMediumDate(AppLocalizations l10n, DateTime date) {
  final String locale = l10n.localeName;
  final DateFormat formatter = _mediumDateCache.putIfAbsent(
    locale,
    () => DateFormat.yMMMd(locale),
  );
  return formatter.format(date);
}

/// Locale-aware medium date plus time (yMMMd + jm), the exact shape of the
/// profile session-expiry row — the one surface that adds the time. Kept as
/// a separate helper so that surface's displayed copy stays byte-identical
/// to the pre-extraction `DateFormat.yMMMd(locale).add_jm()`.
String formatMediumDateTime(AppLocalizations l10n, DateTime date) {
  final String locale = l10n.localeName;
  final DateFormat formatter = _mediumDateTimeCache.putIfAbsent(
    locale,
    () => DateFormat.yMMMd(locale).add_jm(),
  );
  return formatter.format(date);
}
