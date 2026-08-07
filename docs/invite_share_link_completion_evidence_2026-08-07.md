# LegalHub — Invite Share-Link Completion Verification & Evidence Record (2026-08-07)

> **Record type:** follow-up slice close-out evidence (plan
> `docs/invite_share_link_plan_2026-08-07.md`) — records exactly what was
> **verified** about the D-P34.2 **produce** side (commits `b73add5`,
> `2296e05`, `dcfb84b` on `feat/invite-share-link`, plus the plan commit
> `484ff6e` on `main`, no push) and exactly what is **still pending**, with
> no claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-07 — implementation complete, full gate green
> (format clean, analyze clean, suite 857, ledger PASS 171/0/0).** The dated close
> for the P3-plan §13 Q2 row is recorded in this commit (flipped to fully
> RESOLVED), consummating the follow-up the Phase 4.1 close and the P3-plan
> reconciliation flagged: the accept deep link now has both a **consume**
> side (D-P34.2, `95c1676`..`58134f6`) and a **produce** side.

---

## 1. What this record covers

The invite-side **share-link generation** — the last genuine open item the
roadmap / P3-plan / permission-matrix reconciliations surfaced. The consume
side of the accept deep link (`com.legalhub.app://accept-invite?token=<one-time-token>`)
shipped with Phase 4.1 (parser → `PendingAcceptInviteStore` → listener →
accept pre-fill); nothing *produced* the link — an inviter could only
copy a bare token. This slice adds the produce side in four gated slices
(with the review follow-up), all decisions ratified by autonomy (D-IS1..5,
plan §3):

| Slice | Artifact | Commit |
|---|---|---|
| ① — URI builder | `AppLinkParser.acceptInviteUri(String)` — static, pure, dependency-free; builds from the **same `appScheme`/`acceptInviteHost` constants** the parser classifies with (one source of truth); `Uri.queryParameters` encodes any token character; trims; throws `ArgumentError` on a blank token (D-IS5 — mirror of the consume-side never-mint guard) | `b73add5` |
| ② — l10n | `inviteShareLink` / `inviteShareLinkCopied` added to EN/AR/TR ARBs + regenerated localizations (all four generated files carry the getters) | `b73add5` |
| ③ — button + handler | `_copyShareLink` on the invite-success sheet: `acceptInviteUri` → `Clipboard.setData(text: link)` → `inviteShareLinkCopied` snackbar; **FilledButton.icon primary** above the bare-token OutlinedButton; link built **on-demand, never stored or logged** (D-IS3 — same trust model as the existing token copy); zero new deps, no platform config (D-IS4 — the Phase 4.1 intent filters already cover the scheme) | `2296e05` |
| ④ — review follow-up | `pumpAndSettle` after `clearSnackBars` (queued-snackbar determinism); **Back demoted Filled → Outlined** so the token view has one primary; invalid-email test pins "Copy invite link" absent for symmetry | `dcfb84b` |

Decisions D-IS1 (builder on the parser — a separate builder class
rejected), D-IS2 (**clipboard copy, not a native share sheet** — `share_plus`
deferred as a later optional enhancement), D-IS3 (token embedded on-demand,
never stored/logged), D-IS4 (no dependencies added), D-IS5 (blank → throw)
are recorded in plan §3.

## 2. Verified (actually run this session, 2026-08-07)

### 2.1 Final gate on `feat/invite-share-link` (post-`dcfb84b` + Task 4 lockstep)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **857 passed** (exit 0) |
| `scripts/verify_ledger.sh` (canonical docs + plan + evidence) | **PASS 171/0/0** (README 854 in lockstep) |

### 2.2 Test coverage added by the slice (+7 declarations, 847 → 854; suite 850 → 857)

- `test/app/deep_link/app_link_parser_test.dart` (+5): canonical URI shape
  (`com.legalhub.app://accept-invite?token=<t>`); **round-trip**
  `parse(acceptInviteUri(t))` is `AcceptInviteIntent(t)`; special-character
  encoding round-trip (`a&b c=12`); trim; blank token → `throwsArgumentError`.
- `test/features/orgs/presentation/invite_member_sheet_test.dart` (+2):
  **full-URI clipboard pin** — the mocked `Clipboard.setData` channel carries
  the exact deep-link payload (not the bare token) and the
  `inviteShareLinkCopied` snackbar shows; **distinct-payloads pin** — link
  then token sequentially, exactly two `Clipboard.setData` calls with the
  distinct payloads and distinct snackbars, the bare-token copy regression
  untouched.
- No pubspec/platform change in this slice (D-IS4): `flutter/services` was
  already imported; the Android/iOS scheme registrations pre-date it (Phase
  4.1).

## 3. Pending (honestly NOT run — do not read as verified)

- **Live device tap of the produced link (plan R2; reuses the Phase 4.1
  R3/R4 checklist):** the produced URI round-trips through the parser in
  the typed suite only; a real cold/warm tap of the copied link on a device
  is an owner-side smoke, not a widget-test claim.
- **No server change was made or needed** — this slice is client code only
  (plan §1); it consumes the shipped accept screen and the P3.4 invitation
  RPCs as-is.

## 4. Acceptance-criteria status

| Criterion (plan §6) | Status | Evidence |
|---|---|---|
| Builder produces `com.legalhub.app://accept-invite?token=…` from the parser's own constants | **VERIFIED** — `appScheme`/`acceptInviteHost` reused, one source of truth | parser tests, §2.1 |
| Every produced link round-trips as `AcceptInviteIntent` with the identical token | **VERIFIED** — `parse(acceptInviteUri(t)) == AcceptInviteIntent(t)`, incl. encoded special characters | parser tests, §2.1 |
| Blank token is never minted | **VERIFIED** — `acceptInviteUri` trims + throws `ArgumentError` | parser test, §2.1 |
| Copy-share button on the invite-success sheet copies the full URI with a distinct localized snackbar | **VERIFIED** — exact payload + `inviteShareLinkCopied` | widget pins, §2.1 |
| Bare-token copy regression untouched | **VERIFIED** — distinct-payloads pin (two `setData` calls, bare token last) | widget pins, §2.1 |
| Token built on-demand, never stored or logged | **VERIFIED** — no new state; link derived in the handler (D-IS3) | §1 slice ③ |
| Zero new dependencies, no platform config | **VERIFIED** — pubspec untouched this slice (D-IS4) | §2.2 |
| Exit criteria (plan §6): full gate green incl. the new suite; README + ledger in lockstep | **VERIFIED** — format/analyze/test/ledger green; README 847 → **854** | §2.1 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app worktree on feat/invite-share-link>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh <canonical docs + plan + evidence>
```

## 6. Ledger impact

README test count synced **847 → 854** in lockstep with the ledger's
declaration count across the slice (+7). The P3-plan §13 Q2 row flipped from
"RESOLVED (partial) — NOT built" to **fully RESOLVED 2026-08-07** citing the
shipping commits. No schema/RLS/policy change — this slice is client code
only.

## 7. Review findings — resolved (not papered over)

- **Task 3 review (`2296e05`):** no correctness findings — the full-URI pin
  (exact literal payload, catches accidental constant drift) and the
  distinct-payloads pin were confirmed honest (unambiguous exact-match
  finders; the clipboard mock seam is the real `SystemChannels.platform`
  handler; no timers/subscriptions in the sheet). Two robustness/hierarchy
  notes applied in `dcfb84b`: (1) `clearSnackBars()` + a single `pump()`
  left the first snackbar's exit animation mid-flight — queued-snackbar
  visibility then depends on Flutter-version timing, so the pin now
  `pumpAndSettle()`s after clearing; (2) the token view had **two**
  `FilledButton`s ("Copy invite link" + "Back") — Back demoted to
  `OutlinedButton` so the link copy is the single primary action.

## 8. Owner attention needed

- **Device smoke (reuses the Phase 4.1 R3/R4 checklist):** with a
  configured build, invite a member → tap **Copy invite link** → paste the
  link (or tap it on a second device) → expect the accept screen with the
  token pre-filled and Accept still manual; also confirm the link opens
  cold and warm.
- **P3-plan §13 Q2 is now fully RESOLVED (2026-08-07):** paste surface +
  accept deep link (consume) + share-link generation (produce) all shipped;
  email delivery remains explicitly out of scope.
- **Remaining roadmap:** the open items are owner-side only — the Phase 4
  smokes (dashboard Redirect URL R1, device R3/R4) and the D-45.1 live E2E
  (`docs/p3_plan_complete_2026-08-05.md`).
