import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/sample_service.dart';

void main() {
  // Ensure a clean locator between tests; GetIt is a process-global singleton.
  tearDown(resetServiceLocator);

  group('configureDependencies (B3 DI foundation)', () {
    test('registers SampleService', () {
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('resolves SampleService as a lazy singleton', () {
      configureDependencies();

      final SampleService first = serviceLocator<SampleService>();
      final SampleService second = serviceLocator<SampleService>();

      // Lazy singleton: same instance across resolutions.
      expect(identical(first, second), isTrue);
      expect(first.name, 'SampleService');
    });

    test('is idempotent when called more than once', () {
      configureDependencies();
      // Calling again must not throw (guard prevents double registration).
      configureDependencies();

      expect(serviceLocator.isRegistered<SampleService>(), isTrue);
    });

    test('throws when resolving an unregistered dependency', () {
      // Before configureDependencies() runs, nothing is registered.
      expect(() => serviceLocator<SampleService>(), throwsStateError);
    });
  });
}
