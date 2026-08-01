/// The consultation's category, selectable in the booking flow.
///
/// Approved owner decision (D2): these three values are the **only** options
/// the flow may offer — General, Follow-up, and Urgent. No consultation-mode
/// (video/in-person/phone) and no legal-domain categories exist here; adding
/// one requires an explicit owner decision (the enum-pin test in
/// `booking_request_test.dart` enforces this at test level).
///
/// Fake-domain value object: the real data contract is deferred to P2/P3 and
/// this shape is TBD — it is not a backend contract.
enum BookingCategory { general, followUp, urgent }
