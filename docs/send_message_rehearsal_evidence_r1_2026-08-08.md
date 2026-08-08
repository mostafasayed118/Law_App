# LegalHub — Send-Message RPC Rehearsal Evidence (r1, 2026-08-08)

> **Record type:** Ephemeral rehearsal evidence for the audited
> `send_message` RPC slice (plan `docs/send_message_rpc_plan_2026-08-08.md`,
> T4). **Status: PASSED 2026-08-08.** Same infra as the six prior rehearsals
> (matters/documents/messages/storage/realtime read + push): a Docker-backed
> scratch Supabase stack (`supabase start` host, psql shim into the
> container), the harness `--apply` as the real schema-builder from the
> committed `supabase/` files, then the full battery. **Zero contact with
> the dev project** (`eutmvevpskerzpqmwplv` is hard-refused by the harness
> guard). All figures below are the **observed output of the run**, not a
> pasted summary — INSTRUCTIONS.md §1.3 #5.
>
> **What this rehearsal proves (and the honest limit):** the committed
> slice artifacts build cleanly into the post-D-SM3 state (the audited
> RPC + the direct-INSERT revocation), the structural pins hold (11 tables /
> 11 RLS / **10 policies** / publication exactly messages / **19 EXECUTE
> RPCs**), the 01–09 regression batteries stay green, the re-scoped 09
> (delivery equivalence + D-SM3 revocation pins) is green, and the new 10
> battery (the RPC write path: positives, §8 audit row, in-function deny
> rows, empty-body CHECK, §8 negative) is green. **The real configured-build
> client round-trip is NOT claimed here** — that is the env-gated client
> slice (plan T7), never the rehearsal.

---

## 1. Run metadata

| Field | Value |
|---|---|
| Date | 2026-08-08 |
| Host | the session's Docker-backed rehearsal stack (`supabase start`; `supabase_db_supabase` on 127.0.0.1:54322) |
| Slice commits under rehearsal | `7759181` (T1 review) + `60dae71` (T2 artifact) + `b013ee5` (T3 battery/harness + the D-SM3 revocation) — the committed `supabase/` files as the schema-builder |
| Battery | `scripts/verify_policy_tests.sh` (committed harness at `b013ee5`) |
| Dev-project contact | **None** (hard-refused by the harness guard) |
| Status | **PASSED 2026-08-08** |

## 2. Reset discipline (why `--apply` starts clean)

The scratch stack had accumulated applied objects from the realtime-push
T2/T3/T4 sessions and the send-message T2/T3 live checks, so the first
`--apply` on the dirty stack failed on the migrations that create tables
without `IF NOT EXISTS` (17 rejects — the harness targets a **fresh**
project, as its docs state). Per the never-fix-forward discipline, the
stack's `public` schema was reset (`drop schema public cascade; create
schema public;` + the postgres/service_role/anon/authenticated grants — 43
objects cascaded, all rebuilt by `--apply`; the `auth` and `storage`
schemas untouched), then the rehearsal ran from the committed files.

## 3. Rehearsal run (as executed)

```bash
# reset the scratch public schema (clean slate; auth/storage untouched)
psql "$URL" -c "drop schema public cascade; create schema public;
  grant all on schema public to postgres;
  grant all on schema public to service_role;
  grant usage on schema public to anon, authenticated;"

# 1. build from the committed files (README apply order: 01, 02, 04..09
#    migrations, policies/*, rpc/* — send_message.sql carries the function +
#    EXECUTE grant + the D-SM3 revocation)
SUPABASE_TEST_DB_URL="$URL" bash scripts/verify_policy_tests.sh --apply
#    -> 40 passed, 0 failures, RESULT: PASS (incl. "apply send_message.sql")

# 2. the battery
SUPABASE_TEST_DB_URL="$URL" bash scripts/verify_policy_tests.sh
#    -> == summary: 74 passed, 0 warnings, 0 failures == / RESULT: PASS

# 3. harness drift-teeth (no database)
bash scripts/verify_policy_tests.sh --selftest
#    -> 6/6 drift classes detected / RESULT: PASS
```

## 4. Evidence (observed, 2026-08-08)

### 4.1 Structural pins (harness §1, all `[OK]`)

| Pin | Observed |
|---|---|
| Eleven public tables present | **11** |
| RLS enabled on all eleven | **11** |
| Authenticated EXECUTE on `send_message(uuid, text)` (§1d — the 19th RPC) | **true** |
| Policies across the client tables (11 minus the D-SM3 drop) | **10** |
| Live delivery PRESENT (messages in `supabase_realtime`) | **1** |
| Exactly one table in the publication (nothing else) | **1** |

### 4.2 Behavior battery (harness §2, all `[OK]`)

- 00_fixtures seeded · 01/02/03 (identity/membership/owner-boundary)
  green · 04/05/06/07 (matters/documents/messages/storage read) green ·
  08 (message rows/bodies) green.
- **`09_realtime_push.sql` — all checks passed** (re-scoped: publication
  pins 09.01/09.02, privileged empty-body 09.10, delivery equivalence
  09.11–09.14 attorney + client positives / suspended / cross-org / owner /
  stranger negatives, **D-SM3 revocation pins 09.15/09.16**).
- **`10_send_message_rls.sql` — all checks passed** (attorney + client send
  positives with the D-RT4 stored author from profiles; the §8
  `message:create/allowed` redacted audit-row shape; in-function deny rows
  org-role-alone / cross-org / suspended / owner / anon; empty-body CHECK
  through the RPC; §8 negative — exactly the two positive sends' audit rows
  remain).

### 4.3 Verbatim summary

```
== summary: 74 passed, 0 warnings, 0 failures ==
RESULT: PASS
```

### 4.4 Stack state after the run (independent probe)

11 tables / 11 RLS / **10 policies** / publication: messages count **1**,
total **1** / `send_message` EXECUTE **true** / authenticated INSERT on
`messages` **revoked**.

## 5. Static checks (no database)

- `scripts/verify_policy_tests.sh --check` — **337 passed, 0 warnings,
  0 failures** (RESULT: PASS).
- `scripts/verify_policy_tests.sh --selftest` — **6/6 drift classes
  detected** (RESULT: PASS).

## 6. Findings

- **No new findings this run.** The two live-caught defects from the T2/T3
  session stand as already-fixed-and-committed: the `CREATE PUBLICATION`
  no-`IF NOT EXISTS` guard and the 08 SELECT-only grant needing the INSERT
  grant (realtime-push slice), plus this slice's own T3 revision (the 09
  INSERT group → the 10 RPC battery + the D-SM3 revocation pins).
- **Operational note (recorded, not a defect):** the harness `--apply` is
  not idempotent against an already-applied stack (migrations without
  `IF NOT EXISTS`), so a rehearsal always starts from a reset `public`
  schema — this run's reset is documented in §2. The battery itself IS
  re-runnable (the fixtures reset deletes + re-seeds, including
  `audit_events`, so the 10 battery's "exactly 2" audit pin always sees a
  clean baseline).

## 7. Honest limits (NOT claimed by this rehearsal)

- **No real websocket / configured-build round-trip** — the battery's 10
  battery exercises the RPC through role-impersonated EXECUTE calls; the
  client subscription + composer behavior is the env-gated T7 slice
  (needs `.env`, git-ignored; the D-45.1 convention).
- **No dev-project contact** — nothing here touched
  `eutmvevpskerzpqmwplv`; the apply (T5) is owner-gated.
