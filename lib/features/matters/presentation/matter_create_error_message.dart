part of 'matter_create_screen.dart';

/// Maps the typed C-D2 error code to the localized copy; unknown codes fall
/// back to the seam's redaction-safe English message (never empty success —
/// AC-7).
String _errorMessage(AppLocalizations l10n, AppError error) {
  return switch (error.code) {
    'matter_write_denied' => l10n.matterCreateErrorDenied,
    'matter_write_owner_forbidden' => l10n.matterCreateErrorOwnerForbidden,
    'matter_write_assignee_invalid' => l10n.matterCreateErrorAssigneeInvalid,
    'matter_write_validation' => l10n.matterCreateErrorValidation,
    'matter_write_unavailable' => l10n.matterCreateErrorUnavailable,
    'matter_write_failed' => l10n.matterCreateErrorFailed,
    _ => error.userMessage,
  };
}
