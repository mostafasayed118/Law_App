import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/l10n/app_message_l10n.dart';

/// Resolves the label for an [AppError], falling back to [fallback] when the
/// error carries no localization key.
String appErrorLabel(
  AppLocalizations l10n,
  AppError error, {
  required String fallback,
}) => error.messageKey == null
    ? fallback
    : appMessage(l10n, error.messageKey!, args: error.messageArgs);
