/// B3 sample service.
///
/// This exists only to prove the GetIt dependency-injection foundation
/// resolves a registered service (bootstrap spec §7, row B3: "DI resolves a
/// sample service"). It is intentionally non-functional and is NOT a feature,
/// a repository, or a placeholder for any future domain service. B4+ tickets
/// will introduce real `core` primitives with proper contracts.
abstract class SampleService {
  /// Returns a stable, identifying value so tests can assert resolution.
  String get name;
}

/// Default in-memory implementation registered in [configureDependencies].
class SampleServiceImpl implements SampleService {
  const SampleServiceImpl();

  @override
  String get name => 'SampleService';
}
