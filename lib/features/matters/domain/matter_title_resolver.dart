import 'matter.dart';

/// Client-side title-keyed matter resolution for the Phase 12 reverse
/// cross-link (owner decision D-C3).
///
/// The per-matter association is keyed on the **known synthetic matter
/// titles** shared across the fakes (D-W2/D-MSG4), never on ids, so a vault
/// document row's `matterRef` (a title) can be mapped back to the [Matter]
/// it names — the destination of the "View matter" reverse link. This is the
/// D-M5 discipline applied in reverse: resolve from the loaded synthetic
/// list, no per-id fetch, no new gateway method, no RPC.
///
/// Returns null when no matter title matches (the D-C2 unresolved-row case —
/// the row renders no affordance).
Matter? resolveMatterByTitle(List<Matter> matters, String matterRef) {
  for (final Matter matter in matters) {
    if (matter.title == matterRef) {
      return matter;
    }
  }
  return null;
}
