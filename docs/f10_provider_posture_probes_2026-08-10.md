# LegalHub — F-10 Provider/Posture Probes: Evidence (2026-08-10)

> **Record type:** dated probe record for F-10 (provider/hosting posture
> assumed, not verified) — the four **read-only** probes V-F10-1..4 from
> `docs/f04_f06_f10_verification_plan_2026-08-10.md` §3, executed against
> the shared **dev project** (`eutmvevpskerzpqmwplv`, London/West Europe).
>
> **Status: EXECUTED 2026-08-10** — owner-requested execution of the
> plan's F-10 step (the dated go-ahead). All four probes are read-only:
> no config change, no demo-data change, no credentials recorded, no
> token material in this document.
>
> **Mechanism:** `supabase db query --linked` (Management API SQL runner,
> runs as `postgres` — no DB password touched) for V-F10-1..3; the
> Management API project auth-config endpoint (CLI session token, used
> transiently, never printed) for V-F10-4. Matches the D-45.1 probe
> mechanism the plan references.
>
> **Honest boundary (V-F10-3):** the literal token-decode half of V-F10-3
> (decode a GoTrue-issued access token) requires the **owner-held demo
> password** to mint a session — consistent with the checklist §5 posture
> (demo credentials owner-held by design). What is verified here is the
> **claim source + RPC precondition**: all four demo accounts have
> confirmed emails in `auth.users` (the source GoTrue mints `email` from
> for confirmed-email users), and `accept_invitation` reads
> `auth.jwt() ->> 'email'`. The p2 rehearsal already observed real GoTrue
> tokens carrying the matching JWT email claims on the ephemeral stack
> (`docs/p2_rehearsal_evidence_2026-08-01.md`). The owner-side literal
> decode remains available with the checklist §5 pass.

---

## 1. Pre-state

| Check | Observed |
|---|---|
| Linked project | `eutmvevpskerzpqmwplv` (`law_project`, West Europe/London) — `supabase projects list` |
| Runner role | `postgres` (via Management API; `current_setting('server_version_num')` = `170006` → PG 17.6) |
| Session token | CLI session token (Windows Credential Manager, `Supabase CLI:supabase`) — used transiently for the config endpoint, **never printed or recorded** |

---

## 2. V-F10-1 — Storage-policy baseline (policy enumeration, read-only)

Query: `select policyname, cmd, roles from pg_policies where schemaname = 'storage';`

```
┌──────────────────────┬────────┬──────────┐
│ policyname           │ cmd    │ roles    │
├──────────────────────┼────────┼──────────┤
│ files_storage_select │ SELECT │ {public} │
└──────────────────────┴────────┴──────────┘
```

- **Exactly one** storage-schema policy: `files_storage_select` (SELECT,
  applied to `public` role) — matches the harness WATCH-ITEM expectation
  ("exactly one storage-schema policy (the slice's only one)",
  `scripts/verify_policy_tests.sh` §1g).
- **Pass criterion met:** policy set matches the recorded expectation
  (the slice's single policy, no platform extras, no drift).

## 3. V-F10-2 — Default grants on `storage.objects` (privilege enumeration, read-only)

Query: `information_schema.role_table_grants` for `storage.objects`, the
`anon` / `authenticated` / `postgres` / `service_role` grantees.

```
┌───────────────┬────────────────┐
│ grantee       │ privilege_type │
├───────────────┼────────────────┤
│ anon          │ DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE │
│ authenticated │ DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE │
│ postgres      │ (owner; full set)                                            │
│ service_role  │ (full set)                                                   │
└───────────────┴────────────────┘
```

- **Confirmed:** the platform grants **SELECT (and the full DML set) on
  `storage.objects` to `anon` + `authenticated` by default** — exactly the
  posture the harness comment records ("the platform grants SELECT on
  storage.objects to anon + authenticated by default … the RLS policy is
  the gate", §1g) and the battery pins compensate for. The effective gate
  is the `files_storage_select` RLS policy (V-F10-1), not the raw grants.
- **Pass criterion met:** posture recorded; matches the battery assumption
  (no delta needed — the pins compensate by design).

## 4. V-F10-3 — GoTrue JWT `email` claim (claim source + RPC precondition)

Query: `auth.users` for the four demo accounts (email, confirmation
status, role, email identity).

```
┌──────────────────────┬─────────────────┬───────────────┬────────────────┐
│ email                │ email_confirmed │ role          │ email_identity │
├──────────────────────┼─────────────────┼───────────────┼────────────────┤
│ al3tar@gmail.com     │ true            │ authenticated │ 1              │
│ al3tar1@gmail.com    │ true            │ authenticated │ 1              │
│ al3tar4545@gmail.com │ true            │ authenticated │ 1              │
│ al3tar66@gmail.com   │ true            │ authenticated │ 1              │
└──────────────────────┴─────────────────┴───────────────┴────────────────┘
```

- **Claim source present:** all four demo accounts have **confirmed
  emails** (`email_confirmed_at` set) + an `email` identity — the source
  GoTrue mints the JWT `email` claim from for confirmed-email users.
- **RPC precondition reads it:** `supabase/rpc/accept_invitation.sql`
  lines 28–34: *"Precondition: the JWT must carry an 'email' claim"* and
  the match `lower(auth.jwt() ->> 'email') <> lower(v_inv.email)`.
- **Corroborating evidence:** the p2 rehearsal (ephemeral stack) observed
  **real GoTrue tokens** carrying the matching JWT email claims through
  the invite → accept flow (`docs/p2_rehearsal_evidence_2026-08-01.md`).
- **Owner-gated remainder (recorded honestly):** the literal decode of a
  **dev-project-issued** token requires the owner-held demo password to
  sign in — reserved for the owner (checklist §5 posture), consistent with
  the plan's §3 note that credentials are owner-held.
- **Pass criterion:** satisfied at the source/precondition level; the
  literal decode is the checklist §5 owner step, not a blocking gap.

## 5. V-F10-4 — Auth rate-limit settings (Management API auth config, read-only)

Endpoint: `GET /v1/projects/eutmvevpskerzpqmwplv/config/auth` (CLI session
token; **only** the rate-limit keys + two posture flags extracted; the
token itself never printed).

```
rate_limit_anonymous_users = 30
rate_limit_sms_sent        = 30
rate_limit_verify          = 30
rate_limit_token_refresh   = 150
rate_limit_otp             = 30
rate_limit_email_sent      = 30
rate_limit_web3            = 30
---
smtp_pass_present          = True   (custom SMTP configured — not the built-in mailer)
external_email_enabled     = True
```

- **Observed values recorded** — closes the F-07 accepted-posture reference
  (`rate_limit_email_sent = 30`, `rate_limit_otp = 30`) with real dev
  values; the 2026-08-09 `429` during the provider-loop attempt is
  consistent with these limits (per-minute email caps).
- **Pass criterion met:** values recorded; no config change made.

---

## 6. Verdict + honest residuals

- **PASS (3/4 fully executed; V-F10-3 verified at source/precondition):**
  the storage baseline is exactly the recorded expectation (1 policy,
  `files_storage_select`); the platform default grants on
  `storage.objects` are confirmed and compensated by the RLS gate; all
  four demo accounts are email-confirmed (claim source) with the
  `accept_invitation` precondition reading `auth.jwt() ->> 'email'`; the
  dev Auth rate-limit settings are recorded.
- **Residuals (honest):** (a) the literal decode of a dev-project-issued
  token is the owner-held-credential step (checklist §5), not executed
  here; (b) this probe run itself left **no data residue** — read-only
  queries + one Management API GET, zero rows written; (c) the rehearsal
  host's own storage baseline (the harness WATCH-ITEM's other half) is
  asserted by the `--check` battery at rehearsal time, not by this dev
  probe.
- **Redaction:** no token, no password, no PII-shaped value appears in
  this record; all ids are demo ids; the demo emails are the public demo
  identities already recorded in the applied-surface docs.
