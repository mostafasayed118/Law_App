import 'package:equatable/equatable.dart';

import '../../../core/observability/error_reporter.dart';
import 'booking_category.dart';
import 'booking_slot.dart';

/// Transient, backend-free consultation booking request value object.
///
/// Carries the in-progress booking across the flow's steps. It is owned by
/// [BookingCubit] state (approved SPEC AC#8) — it is never threaded through
/// route parameters or GoRouter `extra`. Fake-domain: the real data contract
/// is deferred to P2/P3 and this shape is TBD; it performs no network or
/// persistence work.
///
/// Privacy contract (F1 — mirrors [SignUpRequest], and goes beyond it for
/// [toString]):
/// - [topic] is free text and may carry PII (it could describe a matter).
/// - [toRedactedMap] produces a map that is already sanitized and safe to
///   feed into [AppError.context], delegating to [Redactor.map] so embedded
///   email/bearer patterns are scrubbed; passing it back through
///   [Redactor.map] is idempotent.
/// - [toString] is overridden to return `'[REDACTED]'` because print()/error
///   contexts hit toString(), and Equatable does not guarantee a safe string
///   form for the free-text topic.
class BookingRequest extends Equatable {
  const BookingRequest({
    required this.category,
    this.topic,
    this.slot,
  });

  final BookingCategory category;
  final String? topic;
  final BookingSlot? slot;

  /// A diagnostic-safe map representation (see [Redactor.map] semantics).
  Map<String, Object?> toRedactedMap() => Redactor.map(<String, Object?>{
    'category': category.name,
    'topic': topic,
    'slotId': slot?.id,
  });

  @override
  String toString() => '[REDACTED]';

  @override
  List<Object?> get props => <Object?>[category, topic, slot];
}
