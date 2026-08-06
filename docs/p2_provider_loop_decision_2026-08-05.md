# LegalHub — P2 §4.5 Provider-Loop Decision Capture (2026-08-05)

> **Record type:** Decision capture for the **last DEFERRED residual from
> P2** — the GoTrue **provider-level loop** (signup → email-confirm →
> sign-in → password-reset) that was **NOT executed** against the dev
> project (P2 close decision `docs/p2_close_decision_2026-08-03.md` §2/§3,
> apply execution `docs/p2_apply_execution_2026-08-01.md` §6). Drafted per
> the owner brief using the p0/p2 decision-record conventions
> (`docs/p0_decision_capture.md` "How to use this document";
> `docs/p2_apply_approval_2026-08-01.md` shape).
>
> **Status: DRAFT — decision OPEN; recommendation D-45.1 proposed, NOT yet
> ratified.** Per `docs/p0_decision_capture.md`, a decision without an owner
> and a date is not a decision — this record proposes the decision frame and
> the recommended path; the owner's dated ratification closes it (see §8).
> Drafting this record changes nothing: **no dev-project action, no email
> send, no signup/confirm — zero external effect** (INSTRUCTIONS.md §1.3 #5,
> §5).
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Decided on:** OPEN (pending owner ratification).
>
> **Blocks slice:** the P3 **end-to-end verification** (`docs/p3_auth_org_ux_plan.md`
> §3/§11) — the loop is re-attempted "only if a controlled inbox exists"
> (plan §11). P3.1 (typed `SupabaseAuthApi` + typed gateways + localized
> recovery UX) **shipped 2026-08-05** (`2e18b24`); its evidence record §3
> honestly records the **live dev-project E2E as owner-side/pending**
> (requires `.env`, which stays git-ignored).
>
> **Governed by:** `docs/p2_close_decision_2026-08-03.md` (why deferred) ·
> `docs/p2_apply_execution_2026-08-01.md` §6 (observed facts: `400`
> reserved-TLD, `429` deliberate halt) · `docs/p3_auth_org_ux_plan.md` §3/§11
> (forward hook) · `docs/p0_decision_capture.md` D-05/D-07/D-10a ·
> `docs/p3_1_completion_evidence_2026-08-05.md` §3 · `INSTRUCTIONS.md` §1.3
> #5, §2, §3, §5.

---

## 1. What §4.5 is (the deferred residual, stated precisely)

§4.5 of the P2 apply-approval's execution conditions was the **post-apply
manual smoke** (sign-in / sign-up / password-reset against the applied
schema). At P2 close (2026-08-03, owner decision D-01(b)) the **provider
loop** — the full GoTrue round trip **signup → email-confirm → sign-in →
password-reset** — was **DEFERRED, explicitly NOT PASSED**, and handed to
P3 end-to-end verification as a documented residual risk.

What was verified vs. not (close decision §3):

| Layer | Verdict |
|---|---|
| SQL / RLS / RPC surface (applied slice) | ✅ VERIFIED — Up 1–5 probe battery + r2/r4 rehearsals (38 PASS + 2 RECORDED, twin gates green) |
| Provider-level GoTrue rows (signup → confirm → sign-in → reset) | ⚠️ **NOT VERIFIED** — endpoints proven *live* (unknown-user sign-in → `400 invalid_credentials`; reset → generic `200 {}`) but the loop was **not completed** |

## 2. Why it was deferred (the WHY — recorded accurately from the close decision)

- **D-07 keeps email verification REQUIRED at sign-up** — non-negotiable.
- Dev GoTrue **rejects the reserved-TLD synthetic domains** used by the
  rehearsal fixtures (`400 email_address_invalid`).
- A synthetic gmail-format confirmation attempt then hit
  **`429 over_email_send_rate_limit`** — the **deliberate halt**: continuing
  would have sent real confirmation emails to addresses no one can receive,
  hammering the built-in SMTP rate limit.
- **No controlled inbox exists** on this portfolio project (synthetic data
  only; no mail infrastructure approved).

Therefore the full loop **cannot be completed safely on the dev project
today without either spamming the built-in SMTP or relaxing D-07** — both
out of scope at P2 close.

## 3. Current state — why this decision is timely now (2026-08-05)

- **P3.1 shipped on `main`** (`2e18b24`, merged 2026-08-05): the typed
  `SupabaseAuthApi` sealed-result seam, `SupabaseSignUpGateway`,
  `SupabasePasswordRecoveryGateway`, `PasswordRecoveryCubit`, and the
  localized three-step recovery UX — all green on the typed/fake test suite
  (717 tests, ledger PASS 115).
- The P3.1 evidence record §3 states the **honest boundary**: no live
  dev-project E2E was run this session; the anon-key guard + env-based DI
  flip mean a configured-build E2E is **owner-side** (needs `.env`).
- The P3 plan's §11 forward hook stands: the provider loop is **re-attempted
  only if a controlled inbox exists**.

So the deferred residual is no longer abstract — the client wiring that
*consumes* the loop now exists and is untested against a real provider.
This record decides **how and where** the loop gets completed (or formally
re-closed).

## 4. Design options

| Option | Design | External effect | Verifies | Tradeoffs |
|---|---|---|---|---|
| **A. Controlled inbox on the dev project** | Owner provides/approves a real controlled inbox (a mailbox the owner actually can read — e.g. an owner-held alias or a per-project throwaway domain the owner controls). Run the manual smoke: signup → read confirm email → confirm → sign-in → reset, against the **applied dev project** with `.env` (URL + anon key) | **Yes — real emails** to the controlled inbox; a real signup + confirmed user on the dev project | The **actual** dev GoTrue config + applied schema + client wiring together — the strongest end-to-end claim | Requires owner-held inbox + explicit dated apply-approval (INSTRUCTIONS.md §2.1); creates a real dev user (cleanup discipline); single 429/rate-limit incident is possible (one email per attempt) |
| **B. Ephemeral rehearsal loop (P2 pattern) + local mail catcher** | Build a **throwaway** project from the committed `supabase/` files (migrations/policies/RPCs — the P0C.1 harness already can run SQL; add a `verify_provider_loop.sh` companion), with a **local/dev mail catcher** (e.g. a Mailpit-style inbox or the Supabase local stack) receiving the confirmation email — no real SMTP send | **Zero** — everything on the ephemeral environment; no email leaves the machine | The loop mechanics end-to-end against the **committed slice** (mirrors P2 r1–r4 rehearsals); exercises the typed gateway mapping + recovery flow against a real GoTrue | Does **not** test the dev project's *specific* config (email templates, rate limits, hosting defaults); needs Docker/psql infra — **infra-blocked on this machine today** (same constraint recorded in `docs/p0c1_verification_evidence_2026-08-05.md` §3) |
| **C. Formal re-close (decision-level, no run)** | Record that the loop stays an **accepted residual risk** for the P3.2+ milestone, with the typed/fake suite + endpoint-live evidence (§1) as the standing assurance; re-open only when a controlled inbox is approved | None | Nothing new — codifies the status quo with a dated owner decision | Leaves the provider surface unverified indefinitely; the P3.1 client wiring remains exercised only against fakes/typed seams |

## 5. Recommendation (D-45.1 — proposed)

**Recommended: Option B first, then Option A as the acceptance run —
mirroring the P2 two-phase pattern (rehearsal → apply approval → apply
execution).**

- **Phase 1 (ephemeral, zero external effect):** complete the provider loop
  on a throwaway project built from the committed `supabase/` files with a
  local mail catcher — this proves the **loop mechanics + the P3.1 client
  wiring against a real GoTrue** with no dev-project contact and no real
  email. This is the P2 r1–r4 rehearsal pattern, reused.
- **Phase 2 (dev project, owner-approved):** under the owner's **dated
  apply-approval** and only once a **controlled inbox exists** (the P3 §11
  condition), run the smoke on the dev project with `.env` — the strongest
  claim (actual config + schema + client), with one email per attempt and
  cleanup discipline.

**Why not C alone:** C leaves the residual open without the verification P3.1
unlocked; Phase 1 is cheap, zero-effect, and de-risks Phase 2 to a config
check rather than a first-ever loop run.

**Why B before A:** a failed loop run on the ephemeral project costs nothing;
a failed run on the dev project costs a real email + a real signup attempt.
Rehearse first (P2's never-fix-forward discipline), then apply.

## 6. Risks

| Risk | Mitigation |
|---|---|
| Infra-blocked Phase 1 (no Docker/psql on this machine — recorded for P0C.1) | Do Phase 1 on any Docker-capable machine (or CI runner) using the committed files; the harness already exists (`scripts/verify_policy_tests.sh`); document the run in the same evidence format |
| Dev-project Phase 2 hits the SMTP rate limit again (`429`) | **One email per attempt**, deliberate halt on `429` (the 2026-08-03 precedent); never retry-loop; record the observed response verbatim |
| Real confirmed dev user residue | Cleanup step after the smoke (delete the synthetic user/profile — the same zero-residue discipline as apply §6/§7); the trigger→profile path is proven (r4) so cleanup must cover both |
| `.env`/anon-key handling | `.env` stays git-ignored; anon key only (never service-role); key guard stays first in the provider wiring path |
| D-07 relaxation temptation | **Non-negotiable** — email verification stays REQUIRED; no option here proposes relaxing it |
| Scope creep (P3.2–P3.5 work sneaking in) | This record covers **only** the loop verification; membership hydration, org UX, invite acceptance, owner admin are separate plan slices with their own gates |

## 7. What this DRAFT does NOT authorize

- **No** dev-project action of any kind (no signup, no email send, no
  admin-confirm, no migration/RPC/policy/config change) until the owner's
  **dated apply-approval** for Phase 2 exists (INSTRUCTIONS.md §2.1 gates;
  the P2 apply-approval pattern).
- **No** push (`git push` needs separate explicit approval).
- **No** secrets: no service-role key, no `.env` contents, no real PII in any
  file/commit/log; `.env` stays git-ignored.
- **No** relaxation of D-07 (email verification REQUIRED).
- **No** claim that the loop passed — none of these options has run yet.

## 8. Next steps (owner actions)

1. **Ratify D-45.1** (or amend the recommendation) with a dated one-line
   decision — flipping this record's Status to RATIFIED with a Decision +
   Decided-on.
2. **Phase 1:** schedule the ephemeral rehearsal loop on Docker-capable
   infra; record evidence in a dated file (the P0C.1 evidence format).
3. **Phase 2:** approve a controlled inbox; give the dated apply-approval;
   run the smoke on the dev project with cleanup; record evidence.
4. If infra keeps Phase 1 unavailable for a defined window, the owner may
   instead ratify **Option C** as a dated re-close (residual accepted until
   P3.2+).

## 9. Ledger

- Docs-only draft: no `lib/`/`test/` change (README count untouched;
  `scripts/verify_ledger.sh` unaffected).
- On ratification, the P3 plan's §3/§11 forward-hook rows and the P2 close
  decision's residual-risk line can be pointed at this record (dated
  follow-up, same batch or immediate).
- Nothing pushed; `main` remains 15 commits ahead of `origin/main` at draft
  time (the P3.1 merge + docs records, all local).
