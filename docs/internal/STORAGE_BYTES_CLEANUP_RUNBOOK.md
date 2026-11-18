# Storage-bytes cleanup — owner deployment runbook

**Status: NOT DEPLOYED.** This wave adds the code only. Account deletion remains
PARTIAL on every hosted project until all steps below are completed and verified
by the owner. No migration in this wave has been applied to a live project.

## What was added

- Edge Function `cleanup-deleted-user-storage`
  (`supabase/functions/cleanup-deleted-user-storage/index.ts`): lists objects
  owned by a deleted user in the repo's only bucket (`matter-files`), deletes
  them through the Storage API with the service-role key, verifies the identity
  is gone through the Admin API before deleting, refuses an empty `user_id`,
  is idempotent, and reports `deleted` / `failed` / `bytes` from API responses.
- Mocked Deno tests: `supabase/functions/cleanup-deleted-user-storage/index_test.ts`.
- File-only migration `supabase/migrations/36_storage_bytes_cleanup_wiring.sql`
  (+ `.down.sql`): pg_cron sweeper every 10 minutes; pg_net posts each deleted
  user id to the function. Vault secret **names only** appear in SQL; no value.
- pgTAP 29.15 proves identity deletion still completes when the cleanup is absent.

## Owner steps (in order, on the chosen project)

1. Deploy the function (replace `<project-ref>`):
   ```bash
   supabase functions deploy cleanup-deleted-user-storage --project-ref <project-ref>
   ```
2. Set the service-role key as the function's secret (the function reads
   `SUPABASE_SERVICE_ROLE_KEY` from its environment; never print it):
   ```bash
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key> --project-ref <project-ref>
   ```
3. Store the two trigger secrets in Supabase Vault (SQL Editor — values are
   placeholders, never commit or chat them):
   ```sql
   select vault.create_secret(
     'https://<project-ref>.supabase.co/functions/v1/cleanup-deleted-user-storage',
     'storage_cleanup_function_url'
   );
   select vault.create_secret('<service-role-key>', 'storage_cleanup_service_key');
   ```
4. Apply the new migration to dev after the owner's normal apply approval:
   ```bash
   psql "$SUPABASE_DB_PASSWORD_URL" -v ON_ERROR_STOP=1 \
     -f supabase/migrations/36_storage_bytes_cleanup_wiring.sql
   ```
   Confirm the extensions `pg_cron` / `pg_net` exist on the target project (they
   are preinstalled on Supabase; absent on stock PostgreSQL). The local PG16
   rehearsal could not create them, so the trigger is **UNVERIFIED-LIVE**.
5. Verify with a disposable test user (do not use a real account):
   - upload a small file through the app (path `{org}/{matter}/{filename}`);
   - delete that test account using the in-app flow (expect HTTP 204);
   - confirm `auth.users` no longer has the id and `public.files` has 0 rows;
   - call the function once with the service key (or wait up to 10 minutes for
     the cron sweeper) and confirm `deleted >= 1`, then call again and confirm
     `deleted: 0` (idempotency);
   - confirm the object is gone in Storage (dashboard or Storage API) and that
     the total byte count decreased;
   - confirm `delete_my_account` still returns 204 when the function is absent
     (pgTAP 29.15 covers this locally).
6. Only after the verification above passes, update the UI/privacy wording from
   "partial until deployed" to the verified state. Until then, leave it as is.

## Never

- Do not put a service-role key or Management API token in code, tests, SQL,
  docs, or chat. The function takes it from its environment only.
- Do not apply migration 35 or 36 to any live project from automation; both are
  owner-gated file-only changes.
- Do not claim account deletion is complete before step 5 passes.
