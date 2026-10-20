/// Build-time payment posture (payments slice).
///
/// `PAYMENTS_MODE` is a compile-time `--dart-define`; anything outside the
/// known values (case-insensitive) falls back to [disabled] so a typo can
/// never accidentally enable a live charge path.
enum PaymentMode {
  /// No pay affordance is rendered anywhere.
  disabled,

  /// The deterministic fake gateway: hosted-checkout-shaped UI and simulated
  /// terminal states, with no real charge and no provider call.
  demo,

  /// The Supabase-backed gateway (Paymob hosted checkout). The gateway still
  /// falls back to the fake when the build has no Supabase env configured.
  live;

  /// Reads `PAYMENTS_MODE` (defaults to `disabled`).
  static PaymentMode fromEnvironment() => parse(
    const String.fromEnvironment('PAYMENTS_MODE', defaultValue: 'disabled'),
  );

  /// Case-insensitive parser; unknown values map to [disabled].
  static PaymentMode parse(String value) =>
      switch (value.trim().toLowerCase()) {
        'demo' => demo,
        'live' => live,
        _ => disabled,
      };
}
