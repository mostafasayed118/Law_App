import '../../core/errors/app_error.dart';
import '../../core/errors/result.dart';
import '../../features/notifications/domain/notification.dart';
import '../../features/notifications/domain/notification_gateway.dart';
import 'supabase_notification_api.dart';

/// [NotificationGateway] backed by the Supabase provider via
/// [SupabaseNotificationApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseBillingGateway]): raw rows from the seam become [Notification]
/// VOs, and typed [SupabaseNotificationException]s become [AppError]s. The
/// [Notification] VO and all presentation are untouched — this is the
/// env-gated seam-compatible swap of plan T8. Rows are **redacted metadata
/// only** (D-N3, T1 Q1): no user-identity/content column is ever read, so no
/// PII can cross this boundary.
///
/// **Newest-first contract:** the gateway sorts the mapped rows descending
/// by [Notification.serverTimestamp] before returning (deterministic,
/// testable; no server-side `order` in the data layer — the
/// billing/documents precedent). The `notifications_org_ts` composite index
/// serves the org-gate scan server-side.
class SupabaseNotificationGateway implements NotificationGateway {
  SupabaseNotificationGateway(this._api);

  final SupabaseNotificationApi _api;

  @override
  Future<Result<List<Notification>>> fetchNotifications() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchNotifications();
      final List<Notification> notifications =
          rows.map(_notificationFromRow).toList()..sort(
            (Notification a, Notification b) =>
                b.serverTimestamp.compareTo(a.serverTimestamp),
          );
      return Result<List<Notification>>.success(
        List<Notification>.unmodifiable(notifications),
      );
    } on SupabaseNotificationException catch (e) {
      return Result<List<Notification>>.failure(_mapFailure(e));
    } on FormatException catch (e) {
      // Provider drift (unexpected category/timestamp shape) surfaces
      // loudly, never as a silently wrong notification.
      return Result<List<Notification>>.failure(
        AppError(
          code: 'notification_read_failed',
          userMessage: 'Unable to load notifications. Please try again.',
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw notification row to the [Notification] VO.
  ///
  /// Every cast below is guarded above (id/category/type/summary/
  /// server_timestamp/is_read), so a malformed row surfaces as a typed
  /// FormatException → AppError, never a raw TypeError across the boundary.
  Notification _notificationFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Notification row has no id');
    }
    final Object? category = row['category'];
    if (category is! String || category.isEmpty) {
      throw FormatException('Notification row has no category');
    }
    final Object? type = row['type'];
    if (type is! String || type.isEmpty) {
      throw FormatException('Notification row has no type');
    }
    final Object? summary = row['summary'];
    if (summary is! String || summary.isEmpty) {
      throw FormatException('Notification row has no summary');
    }
    // `server_timestamp` is a timestamptz → PostgREST hands back a Dart
    // DateTime; anything else is provider drift (the invoices
    // malformed-row guard baseline).
    final Object? serverTimestamp = row['server_timestamp'];
    if (serverTimestamp is! DateTime) {
      throw FormatException('Notification row has no server_timestamp');
    }
    final Object? isRead = row['is_read'];
    if (isRead is! bool) {
      throw FormatException('Notification row has no is_read');
    }
    return Notification(
      id: id,
      category: _categoryFromString(category),
      type: type,
      summary: summary,
      serverTimestamp: serverTimestamp,
      isRead: isRead,
    );
  }

  /// Maps the DB `category` value to the [NotificationCategory] enum.
  /// Anything outside the `appointment`/`activity`/`system` CHECK set is
  /// provider drift → loud FormatException (the D-N4 minimal mapping
  /// contract).
  NotificationCategory _categoryFromString(String category) =>
      switch (category) {
        'appointment' => NotificationCategory.appointment,
        'activity' => NotificationCategory.activity,
        'system' => NotificationCategory.system,
        _ => throw FormatException(
          'Notification row has an unmapped category: $category',
        ),
      };

  /// Maps a provider failure to a redaction-safe [AppError]. The technical
  /// message is the provider's own (denial/availability text) — notification
  /// row content never crosses into errors.
  AppError _mapFailure(SupabaseNotificationException e) {
    final (String code, String userMessage) = switch (e.kind) {
      SupabaseNotificationFailureKind.denied => (
        'notification_read_denied',
        'You do not have permission to view these notifications.',
      ),
      SupabaseNotificationFailureKind.providerUnavailable => (
        'notification_read_unavailable',
        'Notifications are temporarily unavailable. Please try again.',
      ),
      SupabaseNotificationFailureKind.unknown => (
        'notification_read_failed',
        'Unable to load notifications. Please try again.',
      ),
    };
    return AppError(
      code: code,
      userMessage: userMessage,
      technicalMessage: e.message,
    );
  }

  @override
  Future<Result<int>> markNotificationsRead(List<String> ids) async {
    if (ids.isEmpty) {
      // D-F5 guard: nothing to mark — no RPC round-trip, an honest 0.
      return const Result<int>.success(0);
    }
    try {
      final int flipped = await _api.markNotificationsRead(ids);
      return Result<int>.success(flipped);
    } on SupabaseNotificationException catch (e) {
      return Result<int>.failure(_mapFailure(e));
    } on Object {
      // A non-seam failure (transport/parse) is a typed unavailable, never
      // a raw exception across the boundary (the read-path precedent).
      return const Result<int>.failure(
        AppError(
          code: 'notification_mark_unavailable',
          userMessage:
              'Notifications are temporarily unavailable. Please try again.',
        ),
      );
    }
  }
}
