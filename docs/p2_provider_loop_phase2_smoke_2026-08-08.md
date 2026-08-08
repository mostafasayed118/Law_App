# LegalHub — P2 §4.5 Provider-Loop Phase 2 Smoke Plan (DRAFT, 2026-08-08)

> **Record type:** The **Phase 2** execution plan for the D-45.1 two-phase
> provider-loop completion (`docs/p2_provider_loop_decision_2026-08-05.md`
> §5/§8, RATIFIED): the **dev-project smoke under a dated apply-approval**,
> only once a **controlled inbox exists** (the P3 §11 condition). Phase 1
> (ephemeral rehearsal loop, zero external effect) is the prerequisite and
> is **NOT yet run** — this plan is DRAFT and authorizes **nothing** until
> §5 preconditions are met and §6 is signed with a date.
>
> **Status: DRAFT — NOT approved, NOT executed.** Zero dev-project effect;
> no email sent; no signup/confirm; no config change. Every execution step
> below is gated on: (1) Phase 1 PASSED, (2) a controlled inbox approved,
> (3) the owner's dated §6 sign-off.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/p2_provider_loop_decision_2026-08-05.md` (D-45.1
> §5 two-phase plan, §6 risks, §7 NOT-authorized) · `docs/p2_close_decision_2026-08-03.md`
> (why deferred) · `docs/p2_apply_execution_2026-08-01.md` §6 (observed
> `400` reserved-TLD / `429` rate-limit halt) · `docs/p3_auth_org_ux_plan.md`
> §3/§11 (the forward hook) · `docs/current_applied_surface_2026-08-08.md`
> (the applied surface the smoke runs against) ·
> `docs/configured_build_e2e_checklist_2026-08-08.md` (D-45.1, the
> companion owner-side checklist) · `docs/p4_plan_complete_2026-08-07.md`
> (R1: the recovery-link Redirect URL on the dashboard) · `INSTRUCTIONS.md`
> §1.3 #5, §2.1, §3, §5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| D-45.1 decision (two-phase plan) | `docs/p2_provider_loop_decision_2026-08-05.md` | ✅ **RATIFIED 2026-08-05** |
| Phase 1 — ephemeral rehearsal loop (zero external effect) | dated evidence record (P0C.1 format) | ⏳ **NOT run** — infra-blocked on this machine (Docker), same constraint recorded in the D-45.1 record §4 Option B + `docs/p0c1_verification_evidence_2026-08-05.md` §3 |
| Applied surface the smoke runs against | `docs/current_applied_surface_2026-08-08.md` | ✅ **live** — 12 tables / 11 public + 1 storage policy / 19 EXECUTE RPCs / anon key only |
| Client wiring under test | typed `SupabaseAuthApi` + `SupabaseSignUpGateway`/`PasswordRecoveryGateway` (`2e18b24`, P3.1) | ✅ committed + suite-green; live round-trip is the point of this smoke |
| Recovery deep-link Redirect URL | dashboard config (R1, `docs/p4_plan_complete_2026-08-07.md`) | ⏳ owner-side check item — required for the reset leg |
| **Controlled inbox** | owner-approved mailbox (real, readable, no reserved TLD) | ⏳ **owner action** — the P3 §11 condition |
| **Phase 2 apply-approval (this record §6)** | this document | ⏳ **DRAFT** — awaiting Phase 1 PASSED + controlled inbox + dated sign-off |
| Phase 2 execution evidence | `docs/p2_provider_loop_phase2_execution_2026-08-___.md` (created on execution) | ⏳ pending |

---

## 2. What the smoke proves (the four legs)

The full GoTrue round trip that was **NOT executed** at P2 close
(`p2_apply_execution_2026-08-01.md` §6 — `400`/`429` halt) and that Phase 1
proves mechanically on the ephemeral stack. On the **dev project** with the
**real client wiring** it proves the strongest claim: actual provider config +
applied schema + typed gateways together.

| # | Leg | Client path exercised | Success signal |
|---|---|---|---|
| L1 | **Sign-in (existing demo account)** | `SupabaseAuthApiImpl.signInWithPassword` → `SupabaseAuthSuccess(snapshot)` | session minted; org/membership hydration renders the partner's 2 orgs (the applied-surface §2 rows) |
| L2 | **Sign-up → pending** | `signUp` with a **new** identity on the controlled inbox → `SupabaseSignUpPending` (D-07: email confirm REQUIRED → no session) | pending state, no session, generic UI state; **not** authenticated |
| L3 | **Email confirm** | owner clicks the confirmation link in the controlled inbox (PKCE deep-link/callback) → confirm | `auth.users.email_confirmed_at` set; profile row created by the applied trigger (`handle_new_user`, display_name from metadata) |
| L4 | **Sign-in (new confirmed user)** | `signInWithPassword` on the confirmed identity | session minted; own profile row readable; **zero** orgs/matters/documents/messages/files/invoices (no membership — honest empty, the matrix contract) |
| L5 | **Password-reset round trip** (optional, same attempt budget) | `resetPasswordForEmail` → email link (`com.legalhub.app://auth/v1/callback`, R1 Redirect URL) → `verifyOtp` → `updateUserPassword` → sign-in with the new password | recovery session minted then signed out; new password works |

**Keyed to the demo accounts:** L1 uses the existing **partner** `8fa94af0-7390-…`
(al3tar66) — the only account with membership rows — so the post-sign-in surface
is the §1 table of `docs/configured_build_e2e_checklist_2026-08-08.md`
(2 orgs / 3 matters / 3 docs / 3 threads / 6 messages / 3 files / 3 invoices).
L2–L5 use a **NEW synthetic identity** — the demo accounts already exist, so a
signup against them returns `emailInUse` (verified mapping in
`SupabaseAuthApiImpl._failureKindFor`) and would not exercise the pending leg.
The controlled inbox receives that one new confirmation email.

---

## 3. Preconditions (ALL must hold before §6 is signed)

- [ ] **Phase 1 PASSED** — the ephemeral rehearsal loop (Docker-capable
      machine or CI runner) proved all five legs against a throwaway project
      built from the committed `supabase/` files with a local mail catcher;
      evidence recorded in the P0C.1 format, dated.
- [ ] **Controlled inbox approved** — a real mailbox the owner can read (an
      owner-held alias or throwaway domain), **not** a reserved TLD (dev
      GoTrue rejects `.test`/`.example` with `400 email_address_invalid`),
      **not** the P2-synthetic gmail-format identity that hit `429`.
- [ ] **`.env` in place** — dev-project **URL + anon key only** (git-ignored;
      never service-role). The anon-key guard in `SupabaseEnv` runs first.
- [ ] **Dashboard Redirect URL** — `com.legalhub.app://auth/v1/callback`
      registered for the dev project (R1, p4 plan-complete) so the L3 confirm
      link and L5 recovery link open correctly.
- [ ] **One-email budget** agreed — exactly one confirmation email (L3) +
      optionally one recovery email (L5) per attempt; deliberate halt on any
      `429` (the 2026-08-03 precedent — never retry-loop).

---

## 4. Guardrails (non-negotiable)

- **One email per attempt; halt on `429`** — record the response verbatim;
  no retry loop (the P2 `429 over_email_send_rate_limit` precedent).
- **D-07 stays** — email verification REQUIRED; no admin-confirm shortcut, no
  relaxing the pending leg. The whole point of L2/L3 is the real pending→
  confirmed transition.
- **Cleanup discipline** — after the smoke: delete the **synthetic user** +
  its profile row (the trigger→profile path is proven, so cleanup must cover
  both; the `delete_my_account` RPC exists for exactly this); verify 0 residue
  (`auth.users` + `profiles` for the synthetic id). The existing demo accounts
  are **untouched**.
- **No secrets / PII** — the synthetic identity and any observed responses are
  recorded redacted (the P2 §6 precedent: "a synthetic gmail-format identity,"
  never the raw address); `.env` stays git-ignored; no service-role key.
- **No scope creep** — this smoke covers **only** the provider loop; no
  migration/RPC/policy/config change; no `lib/` change (client wiring already
  committed `2e18b24`); no push without separate approval.
- **Never fix-forward** — any unexpected provider behavior is recorded as a
  finding and gated, not patched around.

---

## 5. Runbook (executed only after §6 is signed)

```bash
# 0. Baseline probe (read-only)
#     - auth.users count + the 4 demo account ids (verify-don't-guess)
#     - profiles count + the partner 8fa94af0-… row
#     - current surface: 12 tables / 11 public + 1 storage policy / 19 EXECUTE
#       (cross-ref docs/current_applied_surface_2026-08-08.md)

# L1 — sign-in as the partner (existing demo account)
#     flutter run --dart-define-from-file=.env   (owner device/emulator)
#     → expect: 2 orgs, 3 matters, 3 documents, 3 threads, 6 messages,
#       3 files, 3 invoices (the checklist §1 table)

# L2 — sign-up a NEW synthetic identity on the controlled inbox
#     (in-app sign-up screen) → expect SupabaseSignUpPending (no session)
#     → record the app's pending state verbatim

# L3 — email confirm
#     owner opens the confirmation link in the controlled inbox
#     → expect: email_confirmed_at set; profile row created by the trigger
#       (display_name = the submitted metadata name, generic)

# L4 — sign-in as the new confirmed user
#     → expect: session minted; own profile readable; 0 orgs / 0 matters /
#       0 documents / 0 messages / 0 files / 0 invoices (no membership →
#       honest empty, never fabricated rows)

# L5 (optional) — password-reset round trip on the new user
#     resetPasswordForEmail → recovery link (deep link) → verifyOtp →
#     updateUserPassword → sign-in with the new password
#     → expect: recovery session minted then signed out; new password works

# 6. Cleanup (zero residue)
#     delete the synthetic user via delete_my_account (or the matching
#     auth.users + profiles rows) → verify 0 rows remain for the synthetic id
#     → verify the 4 demo accounts + partner rows untouched

# 7. Evidence
#     record everything in docs/p2_provider_loop_phase2_execution_2026-08-___.md
#     (the P0C.1/P2 evidence format: observed vs expected, verbatim responses,
#     redacted identity, cleanup proof, honest limits)
```

---

## 6. Dated apply-approval (DRAFT — not yet signed)

I, the Project Owner, approve the **P2 provider-loop Phase 2 smoke** on the
dev project (`eutmvevpskerzpqmwplv`) per this plan, having confirmed:

- [ ] Phase 1 (ephemeral rehearsal loop) is **PASSED** (evidence dated, P0C.1 format)
- [ ] A controlled inbox is approved and will receive exactly one confirmation email (+ optionally one recovery email)
- [ ] `.env` = dev-project URL + anon key only; the anon-key guard runs first
- [ ] The dashboard Redirect URL `com.legalhub.app://auth/v1/callback` is registered (R1)
- [ ] Cleanup discipline understood: synthetic user + profile removed, 0 residue, demo accounts untouched
- [ ] One-email budget + deliberate `429` halt understood; D-07 stays REQUIRED

**Signed:** ____________________ **Date:** 2026-08-___

---

## 7. Rollback / cleanup pairing (stands by, unexercised unless needed)

- **Partial loop failure (e.g. confirm link invalid):** no schema change was
  made — nothing to roll back; delete the pending synthetic user + any profile
  row; re-attempt under a fresh dated approval (one email per attempt).
- **`429` halt mid-loop:** stop immediately; record verbatim; no retry; the
  next attempt is a separate dated decision.
- **Post-smoke residue:** the synthetic user + profile delete (above); verify
  `auth.users` + `profiles` show exactly the pre-smoke rows after cleanup.
- **Never fix-forward:** any unexpected provider/schema behavior is recorded
  as a finding and gated, never patched around.

---

## 8. Ledger

- **DRAFT 2026-08-08** — docs-only; zero dev-project effect; no `lib/`/`test/`
  change; no email; no signup/confirm; nothing pushed. Ledger unaffected.
- Flipping to APPROVED requires §3 preconditions (incl. Phase 1 PASSED + a
  controlled inbox) and the dated §6 sign-off; execution then produces the
  dated evidence record (§5 step 7) and the D-45.1 §8 checklist items 2–3 are
  completed.
- This plan does NOT authorize any dev-project action until signed — the
  D-45.1 record §7 constraints hold in full.
