# LegalHub — P2 Provider-Loop Phase 1 Rehearsal Spec (DRAFT, 2026-08-08)

> **Record type:** The **Phase 1** execution spec for the D-45.1 two-phase
> provider-loop completion (`docs/p2_provider_loop_decision_2026-08-05.md`
> §5/§8, RATIFIED): the **ephemeral rehearsal loop** — zero external effect,
> proving the GoTrue loop mechanics + the P3.1 client wiring against a **real
> GoTrue** on a throwaway stack, before any dev-project contact (Phase 2,
> `docs/p2_provider_loop_phase2_smoke_2026-08-08.md`).
>
> **Status: DRAFT — spec + harness committed (`scripts/verify_provider_loop.sh`),
> NOT yet executed.** The run needs a Docker/CI host with `supabase start`
> (or a throwaway remote project) — the same infra constraint recorded in
> the D-45.1 record §4 Option B and `docs/p0c1_verification_evidence_2026-08-05.md`
> §3. This record mirrors the policy-battery discipline
> (`scripts/verify_policy_tests.sh` + the P0C.1 evidence format): a
> re-runnable harness, a static `--check` that runs anywhere, and a dated
> evidence record once the loop genuinely runs.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/p2_provider_loop_decision_2026-08-05.md` (D-45.1
> §4 Option B / §5 Phase 1 / §6 risks / §7 NOT-authorized) ·
> `docs/p2_provider_loop_phase2_smoke_2026-08-08.md` (the five legs this
> rehearsal mirrors, §2) · `docs/p2_close_decision_2026-08-03.md` ·
> `docs/p2_apply_execution_2026-08-01.md` §6 (the `400`/`429` precedent) ·
> `docs/p3_auth_org_ux_plan.md` §3/§11 (forward hook) · `INSTRUCTIONS.md`
> §1.3 #5, §2, §5.

---

## 1. What Phase 1 is (precisely)

The GoTrue **provider loop** — **signup → email-confirm → sign-in →
password-reset** — completed on a **throwaway stack** built from the
committed `supabase/` files, with the confirmation/recovery emails landing in
a **local mail catcher** (the Supabase local stack's Inbucket at
`127.0.0.1:54324`). Zero real email leaves the machine; the dev project is
never contacted (hard-refused by the harness's dev-project guard).

This is the P2 r1–r4 rehearsal pattern reused: prove the mechanics on
ephemeral infra first, then apply under a dated approval (Phase 2).

## 2. The harness (`scripts/verify_provider_loop.sh`)

Mirrors `scripts/verify_policy_tests.sh` structure and conventions:

| Mode | What it does | Where it runs |
|---|---|---|
| `--check` | Static validation, no stack: Phase 1 spec + Phase 2 plan + D-45.1 record present; the five-leg marker + mail-catcher mention in the spec; harness self-syntax; the `scripts/README.md` + `supabase/README.md` doc hooks | **Anywhere** with bash + git (wired like the policy-battery `--check`) |
| `--apply` | Builds the ephemeral project from the committed `supabase/` files in the README apply order (migrations 01/02/04–10 + policies + rpc; 03 skipped by design — apply-time token) | Docker/CI host with psql |
| (default) | **The five legs** against the ephemeral stack: L1 sign-in (existing) · L2 sign-up → pending (D-07, no session) · L3 email-confirm via the mail catcher → session + `email_confirmed_at` · L4 sign-in (confirmed) + trigger-created profile · L5 password-reset round trip (recover → recovery email → verify → update → sign-in with the new password) | Docker/CI host with curl + psql |
| `--selftest` | Drift-injection teeth check (scratch worktree; 5 drift classes) — proves `--check` reds when a doc/hook/syntax drifts | Anywhere with bash + git |

**Dev-project guard:** any URL containing the known dev-project ref
(`eutmvevpskerzpqmwplv`) is hard-refused (exit 2) — the loop is
ephemeral-only (the policy-battery's DO-NOT-TOUCH discipline).

**Exit codes:** 0 pass · 1 FAIL · 2 usage/env error.

## 3. Environment (the Docker/CI host run)

```bash
# One-time: start the ephemeral stack (Docker required)
supabase start          # local GoTrue + Postgres + Inbucket mail catcher

# Build the project from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_provider_loop.sh --apply

# Run the five legs (values from `supabase start` output / .env.local)
SUPABASE_HTTP_URL=http://127.0.0.1:54321 \
SUPABASE_ANON_KEY=<anon key> \
INBUCKET_URL=http://127.0.0.1:54324 \
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
PROVIDER_LOOP_EMAIL=provider-loop.<random>@rehearsal.local \
PROVIDER_LOOP_EXISTING_EMAIL=<existing synthetic account> \
PROVIDER_LOOP_EXISTING_PASSWORD=<its password> \
  bash scripts/verify_provider_loop.sh
```

`PROVIDER_LOOP_EMAIL` is the **synthetic signup identity** (any address — the
local mail catcher receives everything; no real SMTP send). L1 is optional
(needs `PROVIDER_LOOP_EXISTING_EMAIL/PASSWORD`); L2–L5 are the core.

## 4. The five legs — expected signals (mirrors the Phase 2 plan §2)

| # | Leg | Expected (the harness asserts) |
|---|---|---|
| **L1** | Sign-in, existing account | HTTP 200 + `access_token` (session minted — applied schema + GoTrue together) |
| **L2** | Sign-up, new identity | HTTP 200 and **no** `access_token` — D-07 pending (email confirm REQUIRED); the `SupabaseSignUpPending` semantics |
| **L3** | Email confirm via mail catcher | confirmation email arrives (poll ≤10×2s); token extracted; verify → HTTP 200 + `access_token`; `auth.users.email_confirmed_at` set |
| **L4** | Sign-in, confirmed user | HTTP 200 + `access_token`; `profiles` row present (the applied `handle_new_user` trigger created it with the metadata display_name) |
| **L5** | Password reset round trip | recover HTTP 200 (generic non-enumerating); recovery email arrives; token verified → session; PUT password; sign-in with the NEW password → HTTP 200 + `access_token` |

## 5. Static gate (runs anywhere — the Phase 1 `--check`)

```bash
bash scripts/verify_provider_loop.sh --check   # -> RESULT: PASS
bash scripts/verify_provider_loop.sh --selftest # -> RESULT: PASS (5/5 drift classes)
```

The `--check` pins: this spec + the Phase 2 plan + the D-45.1 record present;
the five-leg marker + mail-catcher mention in this spec; harness syntax; the
`scripts/README.md` + `supabase/README.md` hooks. **Committed state should be
green on `--check`/`--selftest` before the Docker run** (mirrors the
policy-battery rule).

## 6. Acceptance criteria (AC) — done when

1. `--check` and `--selftest` PASS on the committed harness.
2. The **genuinely executed** Docker/CI run completes **L1–L5 green** (the
   summary `RESULT: PASS`), with the verbatim output captured in the dated
   evidence record (§7) — never claimed without the run (INSTRUCTIONS §1.3 #5).
3. The evidence record records the honest limits: no dev-project contact, no
   real email sent, the synthetic identity redacted, any host-specific
   deviation (e.g. a different confirm-link shape) noted.
4. Phase 2 remains gated: this record's PASS is the **precondition** for the
   dated apply-approval, not a substitute for it.

## 7. Evidence record format (the P0C.1 pattern, filled on execution)

Create `docs/p2_provider_loop_phase1_rehearsal_evidence_r1_2026-08-___.md`
on the day the loop runs, with the P0C.1 evidence structure:

- **Header:** record type, the D-45.1 Phase 1 citation, status (PASSED /
  FAILED / PARTIAL), the **commit the harness ran on**, the stack (Docker
  host + `supabase start` versions), and the honest boundary (ephemeral
  only, zero external effect).
- **§2 Static gate:** the verbatim `--check` + `--selftest` outputs (PASS,
  counts).
- **§3 The five-leg run:** per leg — the verbatim observed response
  (redacted: no raw email address beyond the synthetic id, no password, no
  token material in full), vs the §4 expected signal, verdict. The mail
  catcher's confirmation/recovery messages cited by subject + arrival, never
  by full body.
- **§4 Consistency notes:** the `email_confirmed_at` probe, the
  trigger-created profile row, the reset round trip — each with the exact
  observed values.
- **§5 Honest limits:** what this run does NOT prove (Phase 2's real config
  on the dev project), any infra deviation, the next gate (Phase 2 dated
  apply-approval).
- **§6 Verdict:** **PASSED** (all five legs green) or FAILED with the finding
  recorded — never a partial pass claimed as a pass.

## 8. Ledger

- **DRAFT 2026-08-08** — commits: `scripts/verify_provider_loop.sh` (the
  harness) + this spec + the `scripts/README.md` / `supabase/README.md`
  hooks. Docs + script only; zero dev-project effect; nothing pushed.
- The static `--check`/`--selftest` are proven green on the committed bytes;
  the **live loop run is owner/CI-side** (Docker), exactly like the
  policy-battery r1 rehearsals were.
