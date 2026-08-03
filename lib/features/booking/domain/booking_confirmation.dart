import 'package:equatable/equatable.dart';

/// A synthetic confirmation for a booking persisted into the in-memory fake
/// only.
///
/// Kept as a typed boundary rather than a raw String — the type is the
/// honesty boundary: it carries a synthetic [referenceId] and makes no
/// backend promise. The real data contract is deferred to P2/P3 and this
/// shape is TBD. It carries no PII (no redaction contract applies).
class BookingConfirmation extends Equatable {
  const BookingConfirmation({required this.referenceId});

  final String referenceId;

  @override
  List<Object?> get props => <Object?>[referenceId];
}
