import 'package:equatable/equatable.dart';

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
  });

  final String code;
  final String userMessage;
  final String? technicalMessage;
  final Map<String, Object?> context;

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
  ];
}
