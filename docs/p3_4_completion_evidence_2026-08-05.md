# LegalHub — P3.4 Completion Verification & Evidence Record (2026-08-05)

> **Record type:** Slice P3.4 close-out evidence (plan
> `docs/p3_auth_org_ux_plan.md` §6 P3.4) — records exactly what was
> **verified** about the invitation-acceptance handoff + delete-account
> audit copy (commits `7548ade`..`e24a49e`, all on `main`, no push) and
> exactly what is **still pending**, with no claim beyond what was actually
> run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-05 — implementation complete, full gate green
> on `main` (analyze clean, suite 770, ledger PASS 115).** The dated close
> decision for the P3 plan gate-table rows is recorded in this commit
> (plan §1 rows + roadmap status line + roadmap gate-table row), mirroring
> the P0C / P3.1 / P3.2 / P3.3 close.

---

## 1. What this record covers

Slice P3.4 = **invitation acceptance + account deletion** (plan §6 P3.4).
Gap analysis showed the §6 UI surface was **already shipped by Phase 2**
(slice 2.4 paste-token accept screen with the single non-enumerating
`invalidInvitation` error + accepted state in EN/AR/TR; slice 2.2
delete-account chain — error-tinted confirm → `delete_my_account` → local
sign-out, failure keeps the session — both with tests). The genuine P3.4
deltas are the plan's handoffs, delivered in two gated slices with
decisions ratified by autonomy (D-P34.1..3):

| Slice | Artifact | Commit |
|---|---|---|
| A — accept → re-hydrate + switch (D-P34.1) | Consummates the recorded D-P33.3 forward hook (plan: "on success → re-hydrate memberships + switch to the new org"): on `OrgSuccess` the screen kicks `AuthCubit.hydrate()` so the accepted membership joins `Session.memberships`, derives the newly-joined org from the hydrated-session diff (the membership not present before the accept — D-08, membership-backed), and writes it to `ActiveOrgStore.select()` so the hub lands on the new org. Best-effort: the accepted state is shown first and never blocked; a failed refresh keeps the last-known-good session (cubit diagnostic channel) and a non-resolvable new org simply skips the switch | `7548ade` |
| B — delete-account audit copy (D-P34.3) | The delete chain was complete as shipped; P3.4 adds the plan's "audit-survives semantics explained in copy (not promised as data recovery)" — a subdued note under the confirm body ("Your data is deleted; audit records of your activity are retained.") via a new l10n key + gen-l10n (EN/AR/TR) | `02a0bb3` |
| Review fix | Pre-seed selection survives the first hub seed (`_selectionMadeThisSession` flag); audit copy softened (no unsupported legal claim) | `0d7a6a8` |
| Ledger lockstep | README 761 → 764 → **767** | `dd31081`, `e24a49e` |

D-P34.2: the deep-link token-entry variant stays deferred to the Phase 4
platform intent-filter work (recorded in the screen's doc; paste is the
P3.4 acceptance surface).

## 2. Verified (actually run this session, 2026-08-05)

### 2.1 Final gate on `main` (post-`e24a49e`)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **770 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 767 in lockstep) |

### 2.2 Test coverage added by the slice (+6 declarations, 761 → 767; suite 764 → 770)

- `accept_invitation_screen_test` — harness now provides `AuthCubit` (built
  from the locator's shared fakes — P3.3 Slice B binds the membership
  repository to the org gateway, so the success path exercises the real
  re-hydration derivation) (+2): a valid token re-hydrates the session
  (org-demo → org-demo + joined) and switches `ActiveOrgStore` to the new
  org; a bad token surfaces the localized invalid-invitation error under
  Arabic (RTL bullet).
- `profile_screen_test` — (+2): the cancel-path now asserts the audit note
  renders in the confirm dialog; a new Arabic dialog test pins the title,
  the audit note, and the cancel action resolving in AR.
- `active_org_store_test` — pre-seed selection semantics (review fix) (+3):
  a selection made before the first seed survives that seed (P3.4 accept
  flow); a pre-seed selection the session does not hold falls back; a
  pre-seed selection is consumed by the first seed and never carries into a
  different user.
- The delete → sign-out chain itself was already pinned by the shipped
  Phase 2 tests (cancel keeps session; confirm deletes + signs out; failed
  deletion surfaces localized error + keeps the session) — re-verified
  green in the full suite.

## 3. Pending (honestly NOT run — do not read as verified)

- **P3.5 (platform-owner admin UX) of the plan is ⏳ not started.** The
  remaining plan work is the last P3 row.
- **Live dev-project E2E** (a configured build exercising sign-in →
  hydration → invite → accept → re-hydrate → delete against the real
  RLS/RPC surface) was **not** exercised. All verification above is the
  typed/fake-gateway test suite plus static review; a configured-build
  check remains **owner-side** (requires `.env`, which stays git-ignored),
  per D-45.1 Phase 2 and the P3.1–P3.3 evidence §3 convention.
- **Deep-link token entry** remains deferred to Phase 4 platform
  intent-filter work (D-P34.2) — not implemented in this slice.
- **No server change was made or needed** — P3.4 is client code only
  (plan §1 "code only — no schema/RLS changes"; it consumes the applied
  `accept_invitation` / `delete_my_account` RPCs as-is).

## 4. Acceptance-criteria status

| Criterion (plan §6 P3.4 / §10) | Status | Evidence |
|---|---|---|
| Paste-token entry screen (single generic `invalid invitation` message for not-found/expired/revoked/email-mismatch — no enumeration) | **VERIFIED (pre-existing)** — shipped Phase 2 slice 2.4, tested (valid token, bad token, empty token); re-verified green | `accept_invitation_screen_test` |
| On success → re-hydrate memberships + switch to the new org (D-P33.3 consummated) | **VERIFIED** — success test pins session enrichment (repository-derived) + `ActiveOrgStore` switch to the joined org; best-effort degradation documented | `accept_invitation_screen_test` |
| Delete-account flow: destructive confirmation → `delete_my_account` → local sign-out; audit-survives semantics in copy (not promised as data recovery) | **VERIFIED (chain pre-existing)** — confirm → sign-out pinned; failure keeps the session; **copy added** (EN/AR/TR) and pinned | `profile_screen_test` |
| Tests: token entry success/denial (one message for all failures), delete confirmation → sign-out, RTL | **VERIFIED** — existing + new: success/denial/empty, AR bad-token (RTL), confirm → sign-out (EN), AR delete dialog | §2.1 / §2.2 |
| AC-6 (plan §10): wrong/expired/revoked/foreign token → the single generic message, no enumeration | **VERIFIED (pre-existing)** — non-enumerating `invalidInvitation` mapping (server undifferentiated); re-verified green | `supabase_organization_gateway_test`, accept screen tests |
| Localization/RTL on P3.4 surfaces | **VERIFIED** — new strings resolve in EN/AR/TR (gen-l10n + pins); full suite incl. RTL green | §2.1 / §2.2 |
| Exit criteria (plan §11-P3): suite green incl. EN/AR/TR + RTL + expiry + denial; capability maps stay UX hints (D-08 preserved) | **VERIFIED** — full suite green; the org switch is D-08 client-side context only | §2.1 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
```

## 6. Ledger impact

README test count synced **761 → 764 → 767** in lockstep with the ledger's
declaration count across the slice (+6 tests, two README bumps). Final
state `scripts/verify_ledger.sh` **PASS 115/0/0** with README 767. No
schema/RLS/policy change — this slice is client code only (the two new
l10n keys are the only non-Dart additions, via the standard ARB +
gen-l10n path).

## 7. Review findings — resolved (not papered over)

- **Pre-seed selection clobbered by the first hub seed (Slice A review):**
  the accept screen's `ActiveOrgStore.select()` writes the selection in
  memory, but when the hub had never seeded this session (sign-in →
  settings → accept without visiting the org hub) the first
  `syncFromSession` seed re-derived from `restored ?? session default` —
  and the construction-time restore read happened *before* the select
  persisted, so the accepted org was overwritten by the session default.
  Fixed with a `_selectionMadeThisSession` flag: the seed branch keeps an
  explicit this-session selection when the new session still holds that
  membership (the same validated-application rule as the restore), and the
  flag is consumed by the seed so a restore-applied value is still applied
  once and never carried into a different identity. Pinned by three store
  tests (`0d7a6a8`).
- **Copy nit (Slice B review):** "as required by law" asserted a legal
  basis the `delete_my_account` RPC docs do not state (audit rows survive
  with the actor cleared as a design decision — D-05). The note was
  softened to "Your data is deleted; audit records of your activity are
  retained." in all three locales (`0d7a6a8`).

## 8. Owner attention needed

- **Remaining plan work:** P3.5 (platform-owner admin UX) is the last ⏳
  row of the P3 plan — gated on the applied owner-only metadata RPCs, which
  deny non-owners server-side (client renders denied, never empty-success).
- **Optional live E2E:** a configured-build invite → accept → re-hydrate →
  delete smoke on the dev project (owner-side, needs `.env`) to confirm the
  RLS/RPC surface beyond the typed/fake suite — also D-45.1 Phase 2's
  controlled condition.
- **Recorded forward hook (D-P34.2):** deep-link token entry joins the
  Phase 4 platform intent-filter work; the paste surface is the shipped
  P3.4 acceptance path.
