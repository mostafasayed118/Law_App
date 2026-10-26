import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Maps a gateway [AppError.code] to localized copy. The data layer keeps the
/// wire code; presentation owns the user-facing sentence (the approvals
/// `approval_error_messages` pattern).
String videoErrorMessage(AppLocalizations l10n, AppError error) {
  final String code = error.code;
  if (code == 'provider_not_configured') {
    return l10n.videoProviderNotConfigured;
  }
  if (code == 'video_session_not_found') {
    return l10n.videoErrorNotFound;
  }
  if (code == 'video_session_ended') {
    return l10n.videoErrorEnded;
  }
  if (code == 'video_no_org') {
    return l10n.videoNoOrg;
  }
  if (code == 'video_unauthorized') {
    return l10n.videoErrorUnauthorized;
  }
  if (code == 'video_forbidden') {
    return l10n.videoErrorForbidden;
  }
  if (code.endsWith('_unavailable')) {
    return l10n.videoErrorUnavailable;
  }
  if (code.endsWith('_invalid') || code == 'video_invalid_request') {
    return l10n.videoErrorInvalid;
  }
  return l10n.videoErrorFailed;
}

/// Localized label for a session lifecycle state.
String videoStatusLabel(AppLocalizations l10n, VideoSessionStatus status) =>
    switch (status) {
      VideoSessionStatus.scheduled => l10n.videoStatusScheduled,
      VideoSessionStatus.live => l10n.videoStatusLive,
      VideoSessionStatus.ended => l10n.videoStatusEnded,
      VideoSessionStatus.cancelled => l10n.videoStatusCancelled,
    };
