# Storage-bytes cleanup — owner deployment runbook

**Status as of 2026-11-19: DEPLOYED + LIVE-VERIFIED end-to-end on the dev
project (`eutmvevpskerzpqmwplv`).** The Edge Function, custom token, Vault
secrets and migration 36 are applied. Two verifications passed: (1) direct
calls returned `deleted: 1, bytes: 19` then `deleted: 0`; (2) a disposable user
created + deleted with NO manual function call was swept by the pg_cron job
alone — a `200 {"deleted":1,"failed":[],"bytes":17}` appeared in
`net._http_response` at the 15:50 run, `files_remaining: 0`, `orphans: 0`.
A pg_net argument-order defect (headers must be the 4th arg, params the 3rd, in
pg_net 0.20.4) was found by that E2E check and corrected in migration 36 +
live before the passing run. See "Live verification" below. Do NOT treat any
other project as deployed until the owner deploys and verifies it there.

## What was added

- Edge Function `cleanup-deleted-user-storage`
  (`supabase/functions/cleanup-deleted-user-storage/index.ts`): lists objects
  owned by a deleted user in the repo's only bucket (`matter-files`), deletes
  them through the Storage API with the service-role key, verifies the identity
  is gone through the Admin API before deleting, refuses an empty `user_id`,
  is idempotent, and reports `deleted` / `failed` / `bytes` from API responses.
  Callers are authenticated with a **dedicated custom token** (`CLEANUP_AUTH_TOKEN`),
  never a Supabase API key. Storage metadata is read through the SECURITY DEFINER
  RPC `public.deleted_user_storage_paths(uuid)` because `/rest/v1` never exposes
  the `storage` schema (PGRST106).
- Mocked Deno tests: `supabase/functions/cleanup-deleted-user-storage/index_test.ts`
  (9 tests).
- Migration `supabase/migrations/36_storage_bytes_cleanup_wiring.sql`
  (+ `.down.sql`): pg_cron sweeper every 10 minutes; pg_net posts each deleted
  user id to the function. Vault secret **names only** appear in SQL; no value.
  It creates the RPC above, fixes `storage.objects.owner` (uuid, not the legacy
  `owner_id`), and uses the two-part `net.http_post` / `cron.schedule` /
  `cron.unschedule` names.
- pgTAP 29.15 proves identity deletion still completes when the cleanup is absent.

## Owner steps (in order, on the chosen project)

1. Deploy the function with JWT verification disabled (the function authenticates
   callers itself with the custom token):
   ```bash
   supabase functions deploy cleanup-deleted-user-storage \
     --project-ref <project-ref> --no-verify-jwt
   ```
2. Create a dedicated custom token (any strong random value with a `cln_`
   prefix) and set it as a Supabase project secret named `CLEANUP_AUTH_TOKEN`.
   The Management API accepts this name (it does NOT accept `SUPABASE_`-prefixed
   names, and the legacy `SUPABASE_SERVICE_ROLE_KEY` is deprecated and must not
   be used as the caller credential). Never print the value:
   ```bash
   supabase secrets set CLEANUP_AUTH_TOKEN=<custom-token> --project-ref <project-ref>
   ```
3. Store the two trigger secrets in Supabase Vault (SQL Editor — values are
   placeholders, never commit or chat them). The second value is the **same
   custom token** from step 2:
   ```sql
   select vault.create_secret(
     'https://<project-ref>.supabase.co/functions/v1/cleanup-deleted-user-storage',
     'storage_cleanup_function_url'
   );
   select vault.create_secret('<custom-token>', 'storage_cleanup_service_key');
   ```
4. Apply the new migration to dev after the owner's normal apply approval:
   ```bash
   psql "$SUPABASE_DB_PASSWORD_URL" -v ON_ERROR_STOP=1 \
     -f supabase/migrations/36_storage_bytes_cleanup_wiring.sql
   ```
   Confirm the extensions `pg_cron` / `pg_net` exist on the target project (they
   are available on Supabase; absent on stock PostgreSQL). If they are not yet
   installed, create them first:
   ```sql
   create extension if not exists pg_cron with schema extensions;
   create extension if not exists pg_net with schema extensions;
   ```
5. Verify with a disposable test user (do not use a real account):
   - create a disposable auth user and upload a small file so its
     `storage.objects.owner` is the user's uuid (a real in-app upload sets this
     from the caller JWT; a service-key upload leaves it null);
   - delete that test account using the in-app flow (expect HTTP 204);
   - confirm `auth.users` no longer has the id and `public.files` has 0 rows;
   - call the function with the custom token as `Authorization: Bearer <custom-token>`
     (or wait up to 10 minutes for the cron sweeper) and confirm `deleted >= 1`,
     then call again and confirm `deleted: 0` (idempotency);
   - confirm the object is gone in Storage (dashboard or Storage API) and that
     the total byte count decreased;
   - confirm `delete_my_account` still returns 204 when the function is absent
     (pgTAP 29.15 covers this locally).
6. Only after the verification above passes, update the UI/privacy wording from
   "partial until deployed" to the verified state. On dev this is now done (the
   UI, ADR-0011, privacy policy, release notes and in-app legal copy state the
   verified state, with the ~10-minute and other-projects-stay-partial
   qualifications); any other project stays partial until deployed and verified
   there.

## Live verification (dev project `eutmvevpskerzpqmwplv`, 2026-11-19)

Measured end-to-end with a disposable user (`owner` simulated by setting the
uploaded object's owner uuid, matching a real JWT upload):
- `deleted_users_with_orphan_storage()` and `deleted_user_storage_paths(uuid)`
  exist; cron job `storage-bytes-cleanup` scheduled at `*/10 * * * *`.
- RPC returned the owned object (`metadata.size = 19`) before deletion.
- Admin-API delete of the auth user returned 200.
- Function call #1: `200 {"user_id":"…","deleted":1,"failed":[],"bytes":19}`.
- Function call #2: `200 {"user_id":"…","deleted":0,"failed":[],"bytes":0}`.
- `select count(*) from storage.objects where name like '<uid>%'` → `0`.
- Orphan query → `[]`.

### Cron-only E2E (no manual function call) — 2026-11-19

After finding that direct calls worked but the sweeper's HTTP returned 401, the
root cause was a pg_net 0.20.4 argument-order bug: `net.http_post(url, body,
params, headers, timeout)` — the migration had put the headers jsonb in the 3rd
(`params`) slot and `null` in the headers slot, so requests went out without
`Authorization`. Corrected in migration 36 and applied live. Then a disposable
user was created, a file uploaded with its `owner` set to that uid, the auth
user deleted, and NO function call was made. The pg_cron job alone swept it:
- cron run at `2026-11-19 15:50:00Z` → `succeeded`;
- `net._http_response` → `200 {"user_id":"…","deleted":1,"failed":[],"bytes":17}`;
- `files_remaining: 0`, `orphans: 0`, auth user gone.

Cron firing itself was separately confirmed from `cron.job_run_details`:
`succeeded` at 15:30, 15:40, 15:50 UTC (exact 10-minute boundaries),
active=true, schedule `*/10 * * * *`.

## Never

- Do not put a service-role key, custom token, or Management API token in code,
  tests, SQL, docs, or chat. The function takes its caller token from its
  environment only.
- Do not apply migration 35 or 36 to any live project from automation; both are
  owner-gated changes.
- Do not claim account deletion is complete before step 5 passes.
