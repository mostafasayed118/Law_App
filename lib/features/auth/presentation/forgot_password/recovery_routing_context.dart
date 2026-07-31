import 'package:equatable/equatable.dart';

/// In-memory payload threaded across the forgot-password flow's route
/// transitions so the final reset step can build a real
/// `PasswordRecoveryRequest` instead of placeholder values.
///
/// Privacy contract:
/// - This object carries an [email] (PII) and an [otp] (a short-lived
///   credential). It is passed via GoRouter's in-memory `extra`, **never** via
///   URL path/query parameters, so neither value is written to browser
///   history, logs, or shareable links.
/// - Because `extra` is in-memory, a deep link or refresh yields a `null`
///   extra; consumers must tolerate that by falling back to
///   [RecoveryRoutingContext.empty] (which reproduces the prior placeholder
///   behavior) rather than crashing. The normal end-to-end flow threads real
///   values; that is what closes D-T2.
///
/// This is a routing concern, not a domain value object: it does not redact
/// (the consuming `PasswordRecoveryRequest.toRedactedMap` owns redaction) and
/// it is not a contract for any backend gateway.
class RecoveryRoutingContext extends Equatable {
  const RecoveryRoutingContext({required this.email, required this.otp});

  /// Convenience for direct/deep-link navigation where the prior steps' state
  /// is unavailable. Reproduces the pre-Batch-2 placeholder behavior so the
  /// reset screen remains reachable in tests and on refresh.
  static const RecoveryRoutingContext empty = RecoveryRoutingContext(
    email: '',
    otp: '',
  );

  final String email;
  final String otp;

  @override
  List<Object?> get props => <Object?>[email, otp];
}
