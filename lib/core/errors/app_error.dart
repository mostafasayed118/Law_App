import 'package:equatable/equatable.dart';

/// The typed class of an [AppError] — what kind of failure this is, as opposed
/// to the free-form [AppError.code] string.
///
/// Carried so presentation can render the *right* state instead of flattening
/// every failure into one generic error: a denial is not retryable and an
/// outage is, and showing either as "try again" is false assurance (audit
/// 2026-09-21, M-1). The mapping lives in `core/state/view_state.dart`
/// ([viewStateForFailure]).
enum AppErrorKind {
  /// Anything not otherwise classified — the safe default, so existing
  /// constructions keep their behavior.
  unknown,

  /// The caller is not allowed to see this (RLS denial / permission denied).
  /// Retrying cannot help.
  denied,

  /// The provider was unreachable or failed at the transport level. Retrying
  /// may help.
  unavailable,
}

/// A safe, presentation-ready error crossing a repository/use-case boundary.
///
/// [technicalMessage] and [context] are sanitized before they are retained.
/// Protected content, credentials, and session material must never be passed to
/// this type as diagnostic context.
class AppError extends Equatable {
  const AppError({
    required this.code,
    required this.userMessage,
    this.technicalMessage,
    this.context = const <String, Object?>{},
    this.kind = AppErrorKind.unknown,
  });

  final String code;
  final String userMessage;
  final String? technicalMessage;
  final Map<String, Object?> context;

  /// The typed failure class driving state selection (see [AppErrorKind]).
  final AppErrorKind kind;

  Map<String, Object?> toLogMap() => <String, Object?>{
    'code': code,
    'message': userMessage,
    if (technicalMessage != null) 'technical_message': technicalMessage,
    if (context.isNotEmpty) 'context': context,
  };

  @override
  List<Object?> get props => <Object?>[
    code,
    userMessage,
    technicalMessage,
    context,
    kind,
  ];
}
