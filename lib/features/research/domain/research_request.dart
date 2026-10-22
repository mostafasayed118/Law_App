import 'package:equatable/equatable.dart';

/// A user-triggered research request (design §5; plan 2026-10-22, Task 6).
///
/// The ids are the only context the `research-analyze` function trusts: it
/// re-reads the matter and documents under the caller's JWT so RLS decides
/// what the model may see. [question] is trimmed here and checked by
/// [isValid] against the function's 2..500-character contract.
class ResearchRequest extends Equatable {
  ResearchRequest({
    required String organizationId,
    String? matterId,
    Iterable<String> documentIds = const <String>[],
    required String question,
  }) : organizationId = organizationId.trim(),
       matterId = _trimOrNull(matterId),
       documentIds = List<String>.unmodifiable(documentIds.toSet()),
       question = question.trim();

  final String organizationId;
  final String? matterId;
  final List<String> documentIds;
  final String question;

  static const int minQuestionLength = 2;
  static const int maxQuestionLength = 500;

  /// True when the request can be sent: an organization plus a question
  /// inside the function's bounds. The UI disables generation otherwise and
  /// the gateway re-asserts it before any network call.
  bool get isValid {
    final int length = question.length;
    return organizationId.isNotEmpty &&
        length >= minQuestionLength &&
        length <= maxQuestionLength;
  }

  static String? _trimOrNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => <Object?>[
    organizationId,
    matterId,
    Object.hashAll(documentIds),
    question,
  ];
}
