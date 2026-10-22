import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/pending_approval.dart';

/// Localized status label (design §3).
String approvalStatusLabel(AppLocalizations l10n, ApprovalStatus status) {
  return switch (status) {
    ApprovalStatus.pending => l10n.approvalStatusPending,
    ApprovalStatus.approved => l10n.approvalStatusApproved,
    ApprovalStatus.denied => l10n.approvalStatusDenied,
    ApprovalStatus.cancelled => l10n.approvalStatusCancelled,
  };
}

/// Localized request-kind label (design §3).
String approvalKindLabel(AppLocalizations l10n, ApprovalKind kind) {
  return switch (kind) {
    ApprovalKind.conflict => l10n.approvalKindConflict,
    ApprovalKind.waiver => l10n.approvalKindWaiver,
    ApprovalKind.filing => l10n.approvalKindFiling,
    ApprovalKind.expense => l10n.approvalKindExpense,
    ApprovalKind.other => l10n.approvalKindOther,
  };
}

/// Status icon (paired with the label, never color alone).
IconData approvalStatusIcon(ApprovalStatus status) {
  return switch (status) {
    ApprovalStatus.pending => Icons.hourglass_top,
    ApprovalStatus.approved => Icons.check_circle_outline,
    ApprovalStatus.denied => Icons.cancel_outlined,
    ApprovalStatus.cancelled => Icons.remove_circle_outline,
  };
}
