import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/video/domain/video_gateway.dart';
import 'package:legalhub/features/video/domain/video_session.dart';
import 'package:legalhub/features/video/domain/video_token.dart';
import 'supabase_video_api.dart';

/// Video gateway backed by the five audited RPCs + `video-token` (design §6).
///
/// Raw rows become [VideoSession] VOs, the function's `{ url, token, room }`
/// body becomes a [VideoToken], and typed [SupabaseVideoException]s become
/// [AppError]s with the denied/validation/unavailable classification
/// preserved. A deployment without LiveKit secrets surfaces the exact
/// `provider_not_configured` code — never a synthetic success. The read needs
/// the caller's active organization id, supplied as a resolver so the data
/// layer never imports the app-scoped store.
class SupabaseVideoGateway implements VideoGateway {
  SupabaseVideoGateway(this._api, {required this.organizationId});

  static final RegExp _roomNamePattern = RegExp(r'^room_[a-z0-9]{16,40}$');

  final SupabaseVideoApi _api;
  final String? Function() organizationId;

  @override
  Future<Result<List<VideoSession>>> fetchSessions() async {
    final String? organizationId = this.organizationId();
    if (organizationId == null || organizationId.isEmpty) {
      return Result<List<VideoSession>>.failure(
        const AppError(
          code: 'video_no_org',
          userMessage: 'Select an organization to view video consultations.',
          messageKey:
              AppMessageKey.errSelectAnOrganizationToViewVideoConsultations,
        ),
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _api.listSessions(
        organizationId: organizationId,
      );
      return Result<List<VideoSession>>.success(
        List<VideoSession>.unmodifiable(rows.map(_fromRow)),
      );
    } on SupabaseVideoException catch (e) {
      return Result<List<VideoSession>>.failure(
        _errorFor(
          e,
          prefix: 'video_read',
          deniedMessage:
              'You do not have permission to view video consultations.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToViewVideo,
          validationMessage:
              'Unable to load video consultations. Please try again.',
          validationKey:
              AppMessageKey.errUnableToLoadVideoConsultationsPleaseTryAgain,
          unavailableMessage:
              'Video consultations are temporarily unavailable. Please try again.',
          unavailableKey: AppMessageKey
              .errVideoConsultationsAreTemporarilyUnavailablePleaseTryAgain,
          failedMessage:
              'Unable to load video consultations. Please try again.',
          failedKey:
              AppMessageKey.errUnableToLoadVideoConsultationsPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<List<VideoSession>>.failure(_drift(e));
    }
  }

  @override
  Future<Result<String>> createSession({
    String? matterId,
    String? bookingId,
    DateTime? scheduledAt,
  }) async {
    final String? organizationId = this.organizationId();
    if (organizationId == null || organizationId.isEmpty) {
      return Result<String>.failure(
        const AppError(
          code: 'video_no_org',
          userMessage: 'Select an organization to schedule a consultation.',
          messageKey:
              AppMessageKey.errSelectAnOrganizationToScheduleAConsultation,
        ),
      );
    }
    try {
      final String id = await _api.createSession(
        organizationId: organizationId,
        matterId: _trimOrNull(matterId),
        bookingId: _trimOrNull(bookingId),
        scheduledAt: scheduledAt,
      );
      return Result<String>.success(id);
    } on SupabaseVideoException catch (e) {
      return Result<String>.failure(
        _errorFor(
          e,
          prefix: 'video_create',
          deniedMessage:
              'Only a partner or attorney can schedule a video consultation.',
          deniedKey: AppMessageKey.errOnlyAPartnerOrAttorneyCanScheduleA,
          validationMessage:
              'The consultation could not be scheduled. Check the details and try again.',
          validationKey:
              AppMessageKey.errTheConsultationCouldNotBeScheduledCheckThe,
          unavailableMessage:
              'Scheduling a consultation is temporarily unavailable. Please try again.',
          unavailableKey: AppMessageKey
              .errSchedulingAConsultationIsTemporarilyUnavailablePleaseTry,
          failedMessage:
              'Unable to schedule the consultation. Please try again.',
          failedKey:
              AppMessageKey.errUnableToScheduleTheConsultationPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<String>.failure(_drift(e));
    }
  }

  @override
  Future<Result<VideoToken>> fetchToken(String sessionId) async {
    final String id = sessionId.trim();
    if (id.isEmpty) {
      return Result<VideoToken>.failure(
        const AppError(
          code: 'video_invalid_request',
          userMessage: 'Select a video consultation to join.',
          messageKey: AppMessageKey.errSelectAVideoConsultationToJoin,
        ),
      );
    }
    try {
      final Map<String, dynamic> payload = await _api.fetchToken(id);
      return Result<VideoToken>.success(_tokenFrom(payload));
    } on SupabaseVideoException catch (e) {
      return Result<VideoToken>.failure(
        _errorFor(
          e,
          prefix: 'video_join',
          deniedMessage:
              'You do not have permission to join this consultation.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToJoinThis,
          validationMessage:
              'The consultation is not available to join right now.',
          validationKey:
              AppMessageKey.errTheConsultationIsNotAvailableToJoinRight,
          unavailableMessage:
              'Video calls are temporarily unavailable. Please try again.',
          unavailableKey: AppMessageKey
              .errVideoCallsAreTemporarilyUnavailablePleaseTryAgain,
          failedMessage: 'Unable to join the consultation. Please try again.',
          failedKey: AppMessageKey.errUnableToJoinTheConsultationPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<VideoToken>.failure(_drift(e));
    }
  }

  @override
  Future<Result<void>> markLive(String id) {
    return _write(
      () => _api.markLive(id.trim()),
      prefix: 'video_live',
      deniedMessage: 'You do not have permission to start this consultation.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToStartThis,
      validationMessage: 'This consultation can no longer be started.',
      validationKey: AppMessageKey.errThisConsultationCanNoLongerBeStarted,
      unavailableMessage:
          'Starting the consultation is temporarily unavailable. Please try again.',
      unavailableKey: AppMessageKey
          .errStartingTheConsultationIsTemporarilyUnavailablePleaseTry,
      failedMessage: 'Unable to start the consultation. Please try again.',
      failedKey: AppMessageKey.errUnableToStartTheConsultationPleaseTryAgain,
    );
  }

  @override
  Future<Result<void>> end(String id) {
    return _write(
      () => _api.end(id.trim()),
      prefix: 'video_end',
      deniedMessage: 'Only the creator or a partner can end this consultation.',
      deniedKey: AppMessageKey.errOnlyTheCreatorOrAPartnerCanEnd,
      validationMessage: 'This consultation can no longer be ended.',
      validationKey: AppMessageKey.errThisConsultationCanNoLongerBeEnded,
      unavailableMessage:
          'Ending the consultation is temporarily unavailable. Please try again.',
      unavailableKey: AppMessageKey
          .errEndingTheConsultationIsTemporarilyUnavailablePleaseTry,
      failedMessage: 'Unable to end the consultation. Please try again.',
      failedKey: AppMessageKey.errUnableToEndTheConsultationPleaseTryAgain,
    );
  }

  Future<Result<void>> _write(
    Future<void> Function() write, {
    required String prefix,
    required String deniedMessage,
    required AppMessageKey deniedKey,
    required String validationMessage,
    required AppMessageKey validationKey,
    required String unavailableMessage,
    required AppMessageKey unavailableKey,
    required String failedMessage,
    required AppMessageKey failedKey,
  }) async {
    try {
      await write();
      return const Result<void>.success(null);
    } on SupabaseVideoException catch (e) {
      return Result<void>.failure(
        _errorFor(
          e,
          prefix: prefix,
          deniedMessage: deniedMessage,
          deniedKey: deniedKey,
          validationMessage: validationMessage,
          validationKey: validationKey,
          unavailableMessage: unavailableMessage,
          unavailableKey: unavailableKey,
          failedMessage: failedMessage,
          failedKey: failedKey,
        ),
      );
    } on FormatException catch (e) {
      return Result<void>.failure(_drift(e));
    }
  }

  /// One persisted `video_sessions` row. The room-name shape is asserted so a
  /// malformed row surfaces as provider drift instead of a bad connect target.
  VideoSession _fromRow(Map<String, dynamic> row) {
    final String roomName = _requiredString(row, 'room_name');
    if (!_roomNamePattern.hasMatch(roomName)) {
      throw const FormatException('Video session has an invalid room name');
    }
    return VideoSession(
      id: _requiredString(row, 'id'),
      organizationId: _requiredString(row, 'organization_id'),
      matterId: _optionalString(row['matter_id']),
      bookingId: _optionalString(row['booking_id']),
      roomName: roomName,
      status: _statusOf(row['status']),
      scheduledAt: _optionalDate(row['scheduled_at']),
      startedAt: _optionalDate(row['started_at']),
      endedAt: _optionalDate(row['ended_at']),
      createdBy: _optionalString(row['created_by']),
    );
  }

  /// The `video-token` success body; every field is required and non-empty.
  VideoToken _tokenFrom(Map<String, dynamic> payload) {
    return VideoToken(
      url: _requiredString(payload, 'url'),
      token: _requiredString(payload, 'token'),
      room: _requiredString(payload, 'room'),
    );
  }

  VideoSessionStatus _statusOf(Object? value) => switch (value) {
    'scheduled' => VideoSessionStatus.scheduled,
    'live' => VideoSessionStatus.live,
    'ended' => VideoSessionStatus.ended,
    'cancelled' => VideoSessionStatus.cancelled,
    _ => throw const FormatException('Video session has an unknown status'),
  };

  String _requiredString(Map<String, dynamic> row, String field) {
    final Object? value = row[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Video response has no $field');
    }
    return value;
  }

  DateTime? _optionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const FormatException('Video response has an invalid date');
    }
    return parsed;
  }

  String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Maps a seam failure to a redaction-safe [AppError]. Session data and the
  /// room token never cross into errors; only the provider's own message
  /// crosses as the technical message.
  AppError _errorFor(
    SupabaseVideoException e, {
    required String prefix,
    required String deniedMessage,
    required AppMessageKey deniedKey,
    required String validationMessage,
    required AppMessageKey validationKey,
    required String unavailableMessage,
    required AppMessageKey unavailableKey,
    required String failedMessage,
    required AppMessageKey failedKey,
  }) {
    return switch (e.kind) {
      SupabaseVideoFailureKind.unauthorized => AppError(
        code: 'video_unauthorized',
        userMessage: 'Sign in again to use video consultations.',
        messageKey: AppMessageKey.errSignInAgainToUseVideoConsultations,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.forbidden => AppError(
        code: 'video_forbidden',
        userMessage: deniedMessage,
        messageKey: deniedKey,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.notFound => AppError(
        code: 'video_session_not_found',
        userMessage: 'This video consultation was not found.',
        messageKey: AppMessageKey.errThisVideoConsultationWasNotFound,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.sessionEnded => AppError(
        code: 'video_session_ended',
        userMessage: 'This video consultation has already ended.',
        messageKey: AppMessageKey.errThisVideoConsultationHasAlreadyEnded,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.providerNotConfigured => AppError(
        code: 'provider_not_configured',
        userMessage:
            'Video calls are not configured for this deployment. No call was started.',
        messageKey:
            AppMessageKey.errVideoCallsAreNotConfiguredForThisDeployment,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.validation => AppError(
        code: '${prefix}_invalid',
        userMessage: validationMessage,
        messageKey: validationKey,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.unavailable => AppError(
        code: '${prefix}_unavailable',
        userMessage: unavailableMessage,
        messageKey: unavailableKey,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseVideoFailureKind.unknown => AppError(
        code: '${prefix}_failed',
        userMessage: failedMessage,
        messageKey: failedKey,
        technicalMessage: e.message,
      ),
    };
  }

  /// Provider drift (unexpected row or token shape) surfaces loudly, never as
  /// a silently wrong session or a connect attempt with a missing token.
  AppError _drift(FormatException e) => AppError(
    code: 'video_invalid_response',
    userMessage: 'Unable to read the video consultation. Please try again.',
    messageKey: AppMessageKey.errUnableToReadTheVideoConsultationPleaseTry,
    technicalMessage: e.message,
  );
}
