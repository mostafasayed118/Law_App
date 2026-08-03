/// The practice areas a matter or attorney profile may list.
///
/// Four values mirroring the home dashboard's practice-area fixtures
/// (`l10n.areaCorporate` … `l10n.areaFamily`), which the discovery and matter
/// surfaces reuse for labels — no new l10n keys are needed for the areas
/// themselves. Shared in `core` (Phase 7, slice 7.1) so feature layers never
/// import each other just to name an area: discovery defines attorney
/// profiles over it and matters carry a practice area too. The enum-pin
/// tests (`attorney_test.dart`, `matter_test.dart`) enforce the set, so
/// adding an area is a deliberate owner decision (same discipline as the
/// `BookingCategory` G2 pin).
enum PracticeArea { corporate, civil, criminal, family }
