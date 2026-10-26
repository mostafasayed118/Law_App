import 'package:flutter/material.dart';
import 'package:legalhub/features/compliance/domain/compliance_alert.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Localized status label (design §4).
String alertStatusLabel(AppLocalizations l10n, AlertStatus status) {
  return switch (status) {
    AlertStatus.open => l10n.alertStatusOpen,
    AlertStatus.acknowledged => l10n.alertStatusAcknowledged,
    AlertStatus.resolved => l10n.alertStatusResolved,
  };
}

/// Localized severity label (design §4).
String alertSeverityLabel(AppLocalizations l10n, AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.low => l10n.alertSeverityLow,
    AlertSeverity.medium => l10n.alertSeverityMedium,
    AlertSeverity.high => l10n.alertSeverityHigh,
    AlertSeverity.critical => l10n.alertSeverityCritical,
  };
}

/// Localized alert-kind label (design §4).
String alertKindLabel(AppLocalizations l10n, AlertKind kind) {
  return switch (kind) {
    AlertKind.deadline => l10n.alertKindDeadline,
    AlertKind.conflict => l10n.alertKindConflict,
    AlertKind.retention => l10n.alertKindRetention,
    AlertKind.filing => l10n.alertKindFiling,
    AlertKind.other => l10n.alertKindOther,
  };
}

/// Status icon (paired with the label, never color alone).
IconData alertStatusIcon(AlertStatus status) {
  return switch (status) {
    AlertStatus.open => Icons.radio_button_unchecked,
    AlertStatus.acknowledged => Icons.visibility_outlined,
    AlertStatus.resolved => Icons.check_circle_outline,
  };
}

/// Severity icon (paired with the label, never color alone).
IconData alertSeverityIcon(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.low => Icons.info_outline,
    AlertSeverity.medium => Icons.flag_outlined,
    AlertSeverity.high => Icons.warning_amber_outlined,
    AlertSeverity.critical => Icons.error_outline,
  };
}
