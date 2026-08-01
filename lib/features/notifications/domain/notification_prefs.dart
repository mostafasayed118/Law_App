import 'package:equatable/equatable.dart';

/// Device-local notification preferences (user-level, foundation scope).
///
/// These are pure UX preferences persisted on this device; they carry no
/// backend meaning. Notification *delivery* is a v1 capability — this object
/// only records what the user wants, so the future delivery slice starts
/// from an honest, already-localized state. The categories are deliberately
/// generic (appointment, activity, system): no toggle references a product
/// area that lacks an approved data slice (contract §1), and nothing here
/// promises delivery.
class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    required this.appointmentReminders,
    required this.activityUpdates,
    required this.systemAlerts,
  });

  /// Defaults: every category enabled. Matches typical app behavior for
  /// optional preferences; the user can disable each toggle on the screen.
  const NotificationPrefs.defaults()
    : appointmentReminders = true,
      activityUpdates = true,
      systemAlerts = true;

  /// Missing or unknown keys fall back to the default (enabled) so an old or
  /// partial persisted payload never disables a preference silently.
  factory NotificationPrefs.fromJson(Map<String, Object?> json) {
    return NotificationPrefs(
      appointmentReminders: json['appointmentReminders'] as bool? ?? true,
      activityUpdates: json['activityUpdates'] as bool? ?? true,
      systemAlerts: json['systemAlerts'] as bool? ?? true,
    );
  }

  final bool appointmentReminders;
  final bool activityUpdates;
  final bool systemAlerts;

  NotificationPrefs copyWith({
    bool? appointmentReminders,
    bool? activityUpdates,
    bool? systemAlerts,
  }) {
    return NotificationPrefs(
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      activityUpdates: activityUpdates ?? this.activityUpdates,
      systemAlerts: systemAlerts ?? this.systemAlerts,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'appointmentReminders': appointmentReminders,
    'activityUpdates': activityUpdates,
    'systemAlerts': systemAlerts,
  };

  @override
  List<Object?> get props => <Object?>[
    appointmentReminders,
    activityUpdates,
    systemAlerts,
  ];
}
