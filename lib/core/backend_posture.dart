/// Whether the app is running against the credential-free fakes.
///
/// The per-feature seams flip on `SupabaseEnv.isConfigured`; this singleton
/// exposes the same posture to presentation so a configured build does not
/// render "Demo mode" copy over real server data. Tests that register only a
/// gateway (without this singleton) fall back to the historical local-only
/// posture via [backendIsLocalOnly] in `app/service_locator.dart`.
class BackendPosture {
  const BackendPosture({required this.isLocalOnly});

  final bool isLocalOnly;
}
