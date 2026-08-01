import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/features/notifications/data/in_memory_notification_prefs_store.dart';
import 'package:legalhub/features/notifications/domain/notification_prefs.dart';
import 'package:legalhub/features/notifications/presentation/notification_prefs_cubit.dart';

void main() {
  late InMemoryNotificationPrefsStore seededStore;

  const NotificationPrefs persistedPrefs = NotificationPrefs(
    appointmentReminders: false,
    activityUpdates: false,
    systemAlerts: true,
  );

  group('NotificationPrefsCubit', () {
    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'starts with defaults before load',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      expect: () => <NotificationPrefsState>[],
      verify: (NotificationPrefsCubit cubit) {
        expect(cubit.state.prefs, const NotificationPrefs.defaults());
      },
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'load emits the persisted preferences when a value exists',
      setUp: () async {
        seededStore = InMemoryNotificationPrefsStore();
        await seededStore.write(persistedPrefs);
      },
      build: () => NotificationPrefsCubit(seededStore),
      act: (NotificationPrefsCubit cubit) => cubit.load(),
      expect: () => <NotificationPrefsState>[
        NotificationPrefsState(persistedPrefs),
      ],
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'load keeps defaults when nothing is persisted',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      act: (NotificationPrefsCubit cubit) => cubit.load(),
      expect: () => <NotificationPrefsState>[],
      verify: (NotificationPrefsCubit cubit) {
        expect(cubit.state.prefs, const NotificationPrefs.defaults());
      },
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'setAppointmentReminders persists and emits the updated prefs',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      act: (NotificationPrefsCubit cubit) async {
        await cubit.setAppointmentReminders(false);
      },
      expect: () => <NotificationPrefsState>[
        const NotificationPrefsState(
          NotificationPrefs(
            appointmentReminders: false,
            activityUpdates: true,
            systemAlerts: true,
          ),
        ),
      ],
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'setActivityUpdates persists and emits the updated prefs',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      act: (NotificationPrefsCubit cubit) async {
        await cubit.setActivityUpdates(false);
      },
      expect: () => <NotificationPrefsState>[
        const NotificationPrefsState(
          NotificationPrefs(
            appointmentReminders: true,
            activityUpdates: false,
            systemAlerts: true,
          ),
        ),
      ],
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'setSystemAlerts persists and emits the updated prefs',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      act: (NotificationPrefsCubit cubit) async {
        await cubit.setSystemAlerts(false);
      },
      expect: () => <NotificationPrefsState>[
        const NotificationPrefsState(
          NotificationPrefs(
            appointmentReminders: true,
            activityUpdates: true,
            systemAlerts: false,
          ),
        ),
      ],
    );

    blocTest<NotificationPrefsCubit, NotificationPrefsState>(
      'toggling multiple preferences accumulates in one persisted set',
      build: () => NotificationPrefsCubit(InMemoryNotificationPrefsStore()),
      act: (NotificationPrefsCubit cubit) async {
        await cubit.setAppointmentReminders(false);
        await cubit.setSystemAlerts(false);
      },
      expect: () => <NotificationPrefsState>[
        const NotificationPrefsState(
          NotificationPrefs(
            appointmentReminders: false,
            activityUpdates: true,
            systemAlerts: true,
          ),
        ),
        const NotificationPrefsState(
          NotificationPrefs(
            appointmentReminders: false,
            activityUpdates: true,
            systemAlerts: false,
          ),
        ),
      ],
    );
  });
}
