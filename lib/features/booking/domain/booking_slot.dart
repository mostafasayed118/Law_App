import 'package:equatable/equatable.dart';

/// A synthetic consultation slot offered by the booking date-time step.
///
/// Fake-domain value object: the real data contract is deferred to P2/P3 and
/// this shape is TBD. Slots come only from the fake gateway's fixed synthetic
/// list; no availability logic exists (no cutoffs, weekend rules, or
/// attorney-schedule rules — owner decision D3).
///
/// [durationMinutes] is a synthetic **display attribute** only; it implies no
/// availability or scheduling rule (R1).
class BookingSlot extends Equatable {
  const BookingSlot({
    required this.id,
    required this.startsAt,
    required this.durationMinutes,
  });

  final String id;
  final DateTime startsAt;
  final int durationMinutes;

  @override
  List<Object?> get props => <Object?>[id, startsAt, durationMinutes];
}
