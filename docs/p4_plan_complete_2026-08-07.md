# LegalHub — Phase 4 Plan Complete (2026-08-07)

> **Record type:** The dated **owner decision** that closes the **Phase 4
> plan** (auth plumbing) at the decision level — the P0C/P2/P3 convention:
> one dated record per close, next to each slice's evidence
> (`docs/p4_1_completion_evidence_2026-08-07.md`). It consolidates the
> SHIPPED rows (roadmap §6 + gate-table row 4) and records what is **still
> NOT verified** — the live device deep-link smokes and the dashboard
> Redirect URL — with a concrete checklist, no false assurance
> (INSTRUCTIONS.md §1.3 #5).
>
> **Status: PHASE 4 PLAN COMPLETE — 4.1/4.2 SHIPPED 2026-08-07, client-only
> (no schema/RLS change), full gate green on `main` (format 0-changed,
> analyze clean, suite 850, ledger PASS 115, README 847).** Phase 4's two
> rows are closed: 4.2 (sign-up email-verification UX, 2026-08-03) and 4.1
> (deep-link recovery — recovery half 2026-08-03 + the accept-invitation
> deep link D-P34.2 2026-08-07).
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Decided on:** 2026-08-07.
>
> **Governed by:** `docs/features_roadmap_2026-08-03.md` (roadmap §6 Phase 4
> + gate-table row 4) · `docs/p4_41_deeplink_recovery_scope_2026-08-03.md`
> (4.1 scope note) · `docs/p4_1_deeplink_recovery_plan_2026-08-07.md` (the
> 4.1 delta plan) · `docs/p3_plan_complete_2026-08-05.md` (D-45.1 live E2E,
> the shared owner-side acceptance item) · `INSTRUCTIONS.md` §1.3 #5, §5
> (document manual verification, reason, residual risk), §2 (no secret
> disclosure), §1.3 (synthetic data only).

---

## 1. Decision

The **Phase 4 plan is CLOSED at the decision level** on the strength of its
dated slice closes, each with a verified gate on `main`:

| Row | SHIPPED | Commits | Suite | Evidence |
|---|---|---|---|---|
| 4.2 sign-up email-verification UX ("check your inbox" state closes the false-assurance gap) | 2026-08-03 | `deb72d8` | — | roadmap §6/gate-table row 4 |
| 4.1 deep-link recovery — **recovery half** (link-based + PKCE: Android/iOS intent filters, `AuthFlowType.pkce` + `detectSessionInUri`, `emailRedirectTo`, `recoveryPending` guard) | 2026-08-03 | `1f45d9c` (+ P3.1 `2ff561a`) | — | scope note `docs/p4_41_deeplink_recovery_scope_2026-08-03.md` |
| 4.1 deep-link recovery — **accept-invitation deep link (D-P34.2)** (`AppLinkParser` + `PendingAcceptInviteStore` + `app_links` listener + accept-screen pre-fill, no auto-submit) | 2026-08-07 | `95c1676`..`58134f6` (merged `13543ed`) | 850 | `docs/p4_1_completion_evidence_2026-08-07.md` |

Every commit above is on `main`, **nothing pushed**; the 4.1 delta ran the
full gate **after** its review-finding fix (`6d85eb3`), on the committed
state. Phase 4 is client code only (scope note + plan §1): no migration,
RPC, policy, or config change was made. The accept-invitation deep link
also consummates the **P3 §11 R3** item (deep-link token entry, previously
deferred to Phase 4) and the **D-P34.2** forward hook recorded at the
P3.4/P3.5 closes.

## 2. What is verified vs. what is NOT verified

| Layer | Verdict |
|---|---|
| **Client seams, listener, store, router, screens** (typed/fake/stub suite) | ✅ **VERIFIED** — suite 850 green incl. the parser, store single-delivery, listener cold/warm, recovery-URI untouched, accept pre-fill no-auto-submit, and the two router e2e pins; review findings fixed and pinned in the 4.1 evidence record. |
| **Recovery half config** (manifest/plist filters, PKCE init, `emailRedirectTo`, `recoveryPending` guard) | ✅ **VERIFIED (static + suite)** — reconciled file-by-file in the plan; the shipped `1f45d9c`/`2ff561a` wiring is intact. |
| **Live platform-channel deep link** (a real device opening `com.legalhub.app://accept-invite?token=…` through `app_links` cold and warm — R3/R4) | ⚠️ **NOT VERIFIED** — the `app_links` platform channels are exercised by neither the widget suite nor `flutter analyze`; the listener/parser/store/router behavior is pinned via the stub source only. |
| **Dashboard Redirect URL allowlist (R1)** | ⚠️ **NOT VERIFIED (owner-side)** — the Supabase dashboard must list `com.legalhub.app://auth/v1/callback` for the **recovery** email link to resolve; needs the owner's dashboard. |
| **Live PKCE recovery exchange** (email link → app → `passwordRecovery` → reset screen) | ⚠️ **NOT VERIFIED** — part of the D-45.1 Phase 2 live E2E (see §3); the client half is typed-suite verified only. |

No claim is made that the deferred items passed (§1.3 #5). The plan closes
on the **verified client suite**; the live deep-link smokes remain the
recorded owner-side acceptance items.

## 3. Owner-side live smoke checklist (NOT yet run)

Preconditions: `.env` (URL + **anon** key, git-ignored) in place; a device
or emulator with a configured build. The recovery-email smokes need a
**controlled inbox** + the owner's dashboard session (R1). These items sit
alongside — and partly inside — the P3 plan's D-45.1 Phase 2 checklist
(`docs/p3_plan_complete_2026-08-05.md` §3); the Phase 4 items are:

1. **R1 — dashboard Redirect URL:** add `com.legalhub.app://auth/v1/callback`
   to the Supabase dashboard **Redirect URLs** (the one external config the
   recovery half needs; the accept-invite deep link needs no dashboard
   entry — no PKCE).
2. **R3 — accept-invite cold start:** from a terminated app, open
   `com.legalhub.app://accept-invite?token=<one-time-token>` →
   `/accept-invitation` opens with the token pre-filled; Accept is still
   manual; the token is consumed (single delivery — a second open shows the
   empty paste field).
3. **R4 — accept-invite warm start:** from a running app, open the same link
   → the listener (subscribe-first, `6d85eb3`) still delivers the token;
   signed-out → the auth gate bounces to `/sign-in` and a later signed-in
   visit consumes the buffered token (D-P41.4).
4. **Recovery email link (PKCE end-to-end):** trigger a recovery email via
   the shipped screen → tap the emailed link → the app opens, the PKCE code
   exchanges, `passwordRecovery` fires, and the router's `recoveryPending`
   guard lands on the reset screen. (Also covers the P3.1 localized
   recovery UX live.)
5. **Regression glance:** sign-in → hydration → org management still
   round-trip (the P3 §3 checklist), confirming the listener changes did
   not disturb the shell.

Expected observations to record: every denial/error rendered distinctly
(contract §2.7), no double-processing of the PKCE code (recovery URIs fall
through to supabase_flutter's observer — D-P41.2), and **rollback = no-op**
(no schema change is made by these smokes; any unexpected platform behavior
is captured verbatim, never fixed forward).

## 4. Ledger

- **Phase 4 plan: COMPLETE 2026-08-07** — 4.1 (recovery half +
  accept-invitation deep link) and 4.2 SHIPPED (roadmap §6 bullets + status
  line + gate-table row 4 updated in the slice closes); suite **850**;
  `verify_ledger.sh` **PASS 115/0/0** (doc sweep incl. the 4.1 plan +
  evidence); README 847.
- This decision reconciles **status framing only**. No external action was
  taken against the dev project; nothing is committed/pushed beyond the
  local `main` slice commits; the live smokes stay behind the §3 checklist
  until a configured build + the owner's dashboard/controlled inbox exist.
