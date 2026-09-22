part of 'service_locator.dart';

/// Core stateless seams + app-scoped store/cubit singletons (the
/// bootstrap §4.5 local set: sample service, error reporting, locale,
/// notification prefs, org selection, theme).
void _registerCoreServices({SharedPreferences? preferences}) {
  if (!serviceLocator.isRegistered<SampleService>()) {
    serviceLocator.registerLazySingleton<SampleService>(SampleServiceImpl.new);
  }
  if (!serviceLocator.isRegistered<ErrorReporter>()) {
    serviceLocator.registerLazySingleton<ErrorReporter>(
      ConsoleErrorReporter.new,
    );
  }
  if (!serviceLocator.isRegistered<LocaleStore>()) {
    serviceLocator.registerLazySingleton<LocaleStore>(
      () => preferences == null
          ? InMemoryLocaleStore()
          : SharedPreferencesLocaleStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<NotificationPrefsStore>()) {
    serviceLocator.registerLazySingleton<NotificationPrefsStore>(
      () => preferences == null
          ? InMemoryNotificationPrefsStore()
          : SharedPreferencesNotificationPrefsStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<OrgSelectionStore>()) {
    // Device-local active-org selection (P3.2 D-P32.2): the LocaleStore
    // pattern — SharedPreferences when available, in-memory otherwise.
    serviceLocator.registerLazySingleton<OrgSelectionStore>(
      () => preferences == null
          ? InMemoryOrgSelectionStore()
          : SharedPreferencesOrgSelectionStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<LocaleCubit>()) {
    // App-scoped because MaterialApp and routing share the selected locale.
    serviceLocator.registerLazySingleton<LocaleCubit>(
      () => LocaleCubit(serviceLocator<LocaleStore>()),
      dispose: (LocaleCubit cubit) => cubit.close(),
    );
  }
  if (!serviceLocator.isRegistered<ThemeModeStore>()) {
    // The LocaleStore pattern: SharedPreferences when available, in-memory
    // otherwise (tests / env-less runs).
    serviceLocator.registerLazySingleton<ThemeModeStore>(
      () => preferences == null
          ? InMemoryThemeModeStore()
          : SharedPreferencesThemeModeStore(preferences),
    );
  }
  if (!serviceLocator.isRegistered<ThemeCubit>()) {
    // App-scoped because the root MaterialApp reads the selected mode to
    // pick light/dark/system.
    serviceLocator.registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(serviceLocator<ThemeModeStore>()),
      dispose: (ThemeCubit cubit) => cubit.close(),
    );
  }
}
