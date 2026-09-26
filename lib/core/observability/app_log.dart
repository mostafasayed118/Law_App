import 'package:flutter/foundation.dart';

/// The single diagnostic-logging seam for sanitized client logs (R8,
/// 2026-09-24).
///
/// Six `debugPrint` calls used to sit directly in `lib/` (active-org store,
/// membership hydration, auth hydration). All were sanitized and log-level,
/// so this is hygiene rather than risk — but scattering the primitive means
/// no consistent leveling/redaction point. Route sanitized diagnostics
/// through here; never pass credentials, tokens, or PII (the [Redactor]
/// contract in `error_reporter.dart` owns error payloads).
class AppLog {
  AppLog._();

  /// Writes a sanitized diagnostic line (debug builds only, via
  /// [debugPrint]).
  static void diagnostic(String message) => debugPrint(message);
}
