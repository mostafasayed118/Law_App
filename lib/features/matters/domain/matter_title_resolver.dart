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
///
/// Single-shot convenience: keep this for one-off lookups. Per-row list
/// renders MUST use [buildMatterTitleIndex] + [resolveMatterByTitleIn]
/// instead — calling this per row is O(rows × matters) (audit: N+1-shaped
/// client scan), while the prebuilt index resolves each row in O(1).
Matter? resolveMatterByTitle(List<Matter> matters, String matterRef) {
  for (final Matter matter in matters) {
    if (matter.title == matterRef) {
      return matter;
    }
  }
  return null;
}

/// Builds the title → matter index for one list render.
///
/// First title wins on duplicates (same convention as the linear scan's
/// first match, so resolution results never change — only the cost does).
/// The caller builds this ONCE per list (a screen build, a search refine)
/// and resolves every row against it.
Map<String, Matter> buildMatterTitleIndex(List<Matter> matters) {
  final Map<String, Matter> index = <String, Matter>{};
  for (final Matter matter in matters) {
    index.putIfAbsent(matter.title, () => matter);
  }
  return index;
}

/// Resolves [matterRef] against a prebuilt [buildMatterTitleIndex] index —
/// O(1) per row. Null when no title matches (the D-C2 unresolved-row
/// case — the row renders no affordance).
Matter? resolveMatterByTitleIn(Map<String, Matter> index, String matterRef) {
  return index[matterRef];
}
