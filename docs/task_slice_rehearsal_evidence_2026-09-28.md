# Task-slice rehearsal evidence — 2026-09-28

> **Status update (2026-10-20):** the rehearsal fixes were committed in
> `d3baef5` (the "nothing committed" line below is stale). The four task
> RPCs have since changed from `uuid`/`text`/`void` returns to the persisted
> **`jsonb` row** (the D-SM2 contract the Dart seam always required), and
> battery 17 now pins that shape plus reassignment-clears-acknowledgement.
> This evidence predates those edits: re-run the battery live on the
> ephemeral stack before applying migration 17 anywhere. **Update
> 2026-10-21:** migration 17 + the task policies/RPCs were applied live (see
> `docs/live_apply_2026-10-21.md`); the battery itself still needs an
> ephemeral-stack run.

Live rehearsal of the policy-test battery on an ephemeral local stack,
covering the Gate 3 task-writes slice (battery 17) plus the previously
never-run battery 16. Method: `supabase/README.md` "Running the battery".

## Host

- Ephemeral `supabase start` stack in a scratch dir (outside the repo),
  ports remapped to 54421–54424 (the box's Portfolio-Fixer stack holds
  54321–54324; the live dev ref was never touched — the harness
  hard-refuses it).
- DB URL: `postgresql://postgres:postgres@127.0.0.1:54422/postgres`
  (postgres/superuser role — fixtures seed `auth.users`).
- Client: repo had no native `psql` (EDB download 403s); used the
  pre-existing `C:\Program Files\PostgreSQL\16\bin\psql.exe` via a shim —
  EDB psql requires options BEFORE the dbname arg, so the shim reorders
  the harness's URL-first invocations to URL-last. No repo impact.
- Base commit: `4cb463c` + working-tree slice (task SQL/RPC/battery 17,
  harness wiring). Teardown: `supabase stop --no-backup`, scratch dir
  removed; nothing applied anywhere except the throwaway stack.

## Results (fresh stack, pristine volume)

- `--apply`: **54 passed, 0 failed** — all migrations/policies/RPC incl.
  `17_tasks.sql`, `tasks.sql`, the 4 task RPCs, `16_notification_read_flag.sql`.
- Full battery: **98 passed, 0 warnings, 0 failures — RESULT: PASS**,
  incl. `16_notification_read_flag.sql` and `17_task_rls.sql`.
- `--check` (static): **89 passed, 0 failures**.

## Drift found and fixed live (all re-verified in the passing run)

1. `supabase/tests/15_notification_producer_rls.sql` 15.02 captured
   `send_message()` (returns the row as jsonb since the 2026-09-27
   follow-up) into a `uuid` var — invalid cast, live-only failure.
   Fixed to the battery-10 pattern (`v_row jsonb`, `->> 'id'` null check).
2. Harness §1d probed stale no-arg signatures for the P1.3-bounded RPCs;
   `has_function_privilege` needs exact arg lists. Pinned
   `list_members_metadata(integer, integer)`,
   `read_org_audit(uuid, integer, integer)`,
   `read_platform_audit(integer, integer)` (+ the anon probe).
3. Battery 16 was committed but never wired: `--apply` skipped
   `16_notification_read_flag.sql` and `run_battery` skipped
   `16_notification_read_flag.sql`. Wired both (+ header + README
   apply-order list). Battery 16 now runs and passes live.

## Follow-ups (not blocking)

- `--check` cannot catch PL/pgSQL type errors (finding 1) or signature
  drift (finding 2) — consider a signature cross-check in `--check`.
- Nothing was committed by the rehearsal itself; the fixes above were later
  committed in `d3baef5`.
