-- 36_storage_bytes_cleanup_wiring.sql — scheduled Storage-API byte cleanup
-- Applied to the dev project (eutmvevpskerzpqmwplv) on 2026-11-19 (commit
-- 1d4d594, verified); other projects still need their own owner-gated apply.
--
-- Why Option B (pg_cron sweeper) and not an immediate pg_net call from
-- delete_my_account: the Edge Function authenticates callers with a dedicated
-- custom token (Authorization: Bearer <custom token>), never a Supabase API
-- key (the legacy service-role key is deprecated and REST cannot expose the
-- storage schema). An immediate trigger would have to persist that credential
-- in the database to call the function, which this wave forbids. A scheduled
-- sweeper keeps it in the function's own environment (Supabase secret) and
-- only references VAULT SECRET NAMES here; no secret value appears in SQL,
-- Dart, tests or docs.
--
-- The sweeper is idempotent and only targets identities already gone from
-- auth.users. The Edge Function repeats that guard with the Admin API before
-- deleting anything. Schedule: every 10 minutes — bounded latency with no
-- change to the account-deletion RPC (it keeps returning 204).
--
-- Backout: 36_storage_bytes_cleanup_wiring.down.sql.
begin;

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

create or replace function public.deleted_users_with_orphan_storage()
returns table (user_id uuid)
language sql stable
set search_path = public, pg_temp
as $$
  -- Supabase's storage.objects.owner is a uuid column (not owner_id).
  select distinct o.owner
  from storage.objects o
  where o.bucket_id = 'matter-files'
    and o.owner is not null
    and not exists (
      select 1 from auth.users u where u.id = o.owner
    );
$$;

-- The public /rest/v1 endpoint exposes only public + graphql_public (PGRST106),
-- never storage. This SECURITY DEFINER RPC reads storage.objects inside the
-- database and returns only the caller-targeted rows; it is the single bridge
-- from the Edge Function to storage metadata, callable only by service_role.
create or replace function public.deleted_user_storage_paths(p_user_id uuid)
returns table (bucket_id text, name text, metadata jsonb)
language sql stable
security definer
set search_path = public, pg_temp
as $$
  select o.bucket_id, o.name, o.metadata
  from storage.objects o
  where o.bucket_id = 'matter-files'
    and o.owner = p_user_id;
$$;

create or replace function public.enqueue_deleted_user_storage_cleanup()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_url text;
  v_key text;
  r record;
begin
  -- Names only. The owner stores the values in Supabase Vault.
  select decrypted_secret into v_url
    from vault.decrypted_secrets
   where name = 'storage_cleanup_function_url';
  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'storage_cleanup_service_key';

  if v_url is null or v_key is null then
    raise warning 'storage cleanup secrets are not configured; skipping sweep';
    return;
  end if;

  for r in select user_id from public.deleted_users_with_orphan_storage() loop
    -- pg_net 0.20.4 signature: http_post(url, body, params, headers, timeout_ms).
    -- The 3rd argument is params; headers is the 4th. Passing headers 3rd sends
    -- the request with default headers (no Authorization) and the function 401s.
    perform net.http_post(
      v_url,
      jsonb_build_object('user_id', r.user_id),
      '{}'::jsonb,
      jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_key
      ),
      5000
    );
  end loop;
end;
$$;

revoke all on function public.deleted_users_with_orphan_storage() from public, anon, authenticated;
revoke all on function public.deleted_user_storage_paths(uuid) from public, anon, authenticated;
revoke all on function public.enqueue_deleted_user_storage_cleanup() from public, anon, authenticated;
grant execute on function public.deleted_users_with_orphan_storage() to service_role;
grant execute on function public.deleted_user_storage_paths(uuid) to service_role;
grant execute on function public.enqueue_deleted_user_storage_cleanup() to service_role;

do $$
begin
  begin
    perform cron.unschedule('storage-bytes-cleanup');
  exception when others then
    null; -- no prior schedule
  end;
  perform cron.schedule(
    'storage-bytes-cleanup',
    '*/10 * * * *',
    'select public.enqueue_deleted_user_storage_cleanup();'
  );
end $$;

commit;
