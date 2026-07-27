import 'package:get_it/get_it.dart';

import '../core/sample_service.dart';

/// The application's single GetIt service-locator instance.
///
/// Bootstrap spec §4.5 authorizes GetIt as the dependency-injection mechanism.
/// Registrations are kept minimal and limited to the B3 scope: a single sample
/// service that proves the locator resolves dependencies. No feature, network,
/// persistence, or auth services are registered here.
final GetIt serviceLocator = GetIt.instance;

/// Registers all application dependencies.
///
/// Must be called once during application bootstrap (see `main.dart`) before
/// any dependency is resolved. Safe to call again only in tests after
/// [resetServiceLocator] has cleared prior registrations.
void configureDependencies() {
  // Lazy singleton: stateless service, created on first resolution.
  // Per §4.5, stateless services/repositories register as lazy singletons;
  // Cubits (none at B3) would register as factories.
  if (!serviceLocator.isRegistered<SampleService>()) {
    serviceLocator.registerLazySingleton<SampleService>(SampleServiceImpl.new);
  }
}

/// Clears all registrations. Intended for tests that need a clean locator.
Future<void> resetServiceLocator() async {
  await serviceLocator.reset();
}
